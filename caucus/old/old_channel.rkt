#lang racket
(require racket/set)
(require "channel_struct.rkt")

(provide make-abstract-registry make-candidate make-stubborn-candidate make-voter make-greedy-voter make-stubborn-voter make-sleepy-voter make-vote-leader make-region-manager stupid-sort)

(define caucus-log (make-logger 'caucus (current-logger)))

;; Log information in a thread-safe manner
;; NOTE requires using `info@caucus` as the log-level when program is executed
(define (log-caucus-evt evt . vals)
  (log-message caucus-log 'info (logger-name caucus-log) (apply format evt vals)))

;;;; HELPERS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; filters out all candidates that appear in the set
;; (Listof Candidate) (Setof Candidate) -> (Listof Candidate)
(define (filter-candidates candidates blacklist)
  (filter (λ (cand) (not (set-member? blacklist (candidate-name cand)))) candidates))

(define (filter-voters voters blacklist)
  (filter (λ (voter) (not (set-member? blacklist (voter-name voter)))) voters))

(define (make-abstract-registry)
  (log-caucus-evt "Abstract registry is in business!")
  (define publisher-chan (make-channel))
  (define subscriber-chan (make-channel))

  (thread
    (thunk
      (let loop ([data (set)]
                [subscribers (set)])
        (sync
          (handle-evt
            publisher-chan
            (match-lambda
              [(publish val)
               (log-caucus-evt "New value ~a has been published!" val)
               (define new-data (set-add data val))
               (for ([subscriber subscribers]) (channel-put subscriber (payload new-data)))
               (loop new-data subscribers)]
              [(withdraw val)
               (log-caucus-evt "Value ~a is being removed from the registry!" val)
               (define new-data (set-remove data val))
               (loop new-data subscribers)]))
          (handle-evt
            subscriber-chan
            (match-lambda
              [(subscribe subscriber-chan)
               (log-caucus-evt "New subscriber ~a is following the registry!" subscriber-chan)
               (channel-put subscriber-chan (payload data))
               (loop data (set-add subscribers subscriber-chan))]
              [(message response-chan)
               (log-caucus-evt "Channel ~a has requested a message from the registry!" response-chan)
               (channel-put response-chan (payload data))
               (loop data subscribers)]))))))
      (values publisher-chan subscriber-chan))

;; Create a Candidate thread
;; Name Tax-Rate Candidate-Registry -> void
(define (make-candidate name tax-rate threshold registration-chan)
  (define results-chan (make-channel))
  (define cand-struct (candidate name tax-rate results-chan))
  (thread 
    (thunk
      (log-caucus-evt "Candidate ~a has entered the race!" name)
      (channel-put registration-chan (publish cand-struct))
      (let loop ()
        (digest-results cand-struct threshold registration-chan)
        (loop)))))

;; Create a Candidate that tries re-inserting itself into the race
;; Name TaxRate Threshold Chan -> void
(define (make-stubborn-candidate name tax-rate threshold registration-chan)
  (define results-chan (make-channel))
  (define cand-struct (candidate name tax-rate results-chan))
  (thread
    (thunk
      (log-caucus-evt "Stubborn Candidate ~a has entered the race!" name)
      (channel-put registration-chan (publish cand-struct))
      (let loop ()
        (define still-in-race? (digest-results cand-struct threshold registration-chan))
        (when (not still-in-race?)
          (channel-put registration-chan (publish cand-struct))
          (log-caucus-evt "Stubborn Candidate ~a is trying to re-enter the race!" name)
          (loop))))))

;; receive and handle votes from latest election round
;; Candidate Threshold Boolean Chan
(define (digest-results cand threshold reg-chan)
  (define name (candidate-name cand))
  (define results-chan (candidate-results-chan cand))

  (define msg (channel-get results-chan))
  (match msg
    [(ballot-results votes)
     (cond
      [(< (hash-ref votes name 0) threshold)
       (channel-put reg-chan (withdraw name))
       (log-caucus-evt "Candidate ~a has submitted a request to drop out of the race!" name)
       #f]
      [else #t])]
    [(loser name) #f]))

;; Make a Voter thread
(define (make-voter name region rank-candidates voter-registry candidate-registry)
  (define (normal-voting existing-candidates available-candidates leader-chan)
    (define priorities (rank-candidates (set->list existing-candidates)))
    (define voting-for
      (for/first ([candidate (in-list priorities)]
                  #:when (member (candidate-name candidate) available-candidates))
                 (candidate-name candidate)))
    (log-caucus-evt "Voter ~a has submitted a vote for candidate ~a!" name voting-for)
    (announce-vote leader-chan (vote name voting-for)))

  (voter-skeleton name region normal-voting voter-registry candidate-registry))

;; Make a voter thread that produces a greedy voter (who votes multiple times)
(define (make-greedy-voter name region rank-candidates voter-registry candidate-registry)
  (define (greedy-voting existing-candidates available-candidates leader-chan)
    (define priorities (rank-candidates (set->list existing-candidates)))
    (define voting-for
      (for/first ([candidate (in-list priorities)]
                  #:when (member (candidate-name candidate) available-candidates))
                (candidate-name candidate)))

    (define second-vote
      (for/first ([candidate (in-list priorities)]
                  #:when (and (member (candidate-name candidate) available-candidates) (not (string=? (candidate-name candidate) voting-for))))
                  (candidate-name candidate)))
    (log-caucus-evt "Greedy voter ~a is submitting two votes!" name)
    (announce-vote leader-chan (vote name voting-for))
    (announce-vote leader-chan (vote name (if second-vote second-vote voting-for))))

  (voter-skeleton name region greedy-voting voter-registry candidate-registry))

;; Make a voter thread that always votes for the same candidate
(define (make-stubborn-voter name region favorite-candidate voter-registry candidate-registry)
  (define (stubborn-voting existing-candidates available-candidates leader-chan)
    (log-caucus-evt "Stubborn voter ~a is voting for ~a again!" name favorite-candidate)
    (announce-vote leader-chan (vote name favorite-candidate)))

  (voter-skeleton name region stubborn-voting voter-registry candidate-registry))

;; Make a voter that sleeps through their vote (doesn't vote)
(define (make-sleepy-voter name region voter-registry candidate-registry)
  (define (sleepy-voting x y z)
    (log-caucus-evt "Sleepy voter ~a has slept through their vote!" name))

(voter-skeleton name region sleepy-voting voter-registry candidate-registry))

;; Submit a vote to the vote leader
;; NOTE this is put in another thread to prevent deadlocks in voters
;; Chan Vote -> thread
(define (announce-vote leader-chan vote)
  (thread (thunk (channel-put leader-chan vote))))

;; Create a voter thread
;; Name Region ((Listof Candidate) (Listof Candidate) Chan -> thread w/vote) Chan Chan -> voter thread
(define (voter-skeleton name region voting-procedure voter-registry candidate-registry)
  (define receive-candidates-chan (make-channel))
  (define voting-chan (make-channel))
  (thread
    (thunk
      (log-caucus-evt "Voter ~a is registering!" name)
      (channel-put candidate-registry (subscribe receive-candidates-chan))
      (channel-put voter-registry (publish (voter name region voting-chan)))
      (let loop ([candidates (set)])
        (sync
          (handle-evt
            receive-candidates-chan
            (match-lambda
              ;; A response from the Candidate Registry has been received!
              [(payload curr-candidates) (loop curr-candidates)]))
          (handle-evt
            voting-chan
            (match-lambda
              ;; A request to vote has been received from the Vote Leader!
              [(request-vote available-candidates leader-chan)
               (voting-procedure candidates available-candidates leader-chan)
               (loop candidates)])))))))

;; Make the Vote Leader thread
;; Region Chan Chan Chan -> vote leader thread
(define (make-vote-leader region candidate-registry voter-registry results-chan)
  (define retrieve-candidates-chan (make-channel))
  (define retrieve-voters-chan (make-channel))
  (define voting-chan (make-channel))
  (thread
    (thunk
      (sleep 1) ;; to make sure all other actors get situated first
      (log-caucus-evt "The Vote Leader in region ~a is ready to run the caucus!" region)

      ;; Start a sequence of votes to determine an elected candidate
      ;; (Setof Name) (Setof Name) -> Candidate
      (define (run-caucus candidate-blacklist voter-blacklist)
        ;; Determine the next set of eligible candidates
        ;; (Setof Name) -> (Setof Candidate)
        (define (receive-candidates candidate-blacklist)
          (channel-put candidate-registry (message retrieve-candidates-chan))
          (define cand-payload (channel-get retrieve-candidates-chan))
          (match cand-payload
            [(payload new-candidates)
            (list->set (filter-candidates (set->list new-candidates) candidate-blacklist))]))

        ;; Determine the next set of eligible voters
        ;; (Setof Name) -> (Setof Voter)
        (define (receive-voters voter-blacklist)
          (channel-put voter-registry (message retrieve-voters-chan))
          (define voter-payload (channel-get retrieve-voters-chan))
          (match voter-payload
            [(payload new-voters)
             (list->set (filter-voters (set->list new-voters) voter-blacklist))]))

        ;; Issue ballots to all eligible voters and return each voter's voting channel
        ;; (Setof Voter) (Setof Candidate) -> (Hashof Name -> Chan)
        (define (issue-votes eligible-voters eligible-candidates)
          (log-caucus-evt "Vote leader in region ~a is issuing a vote!" region)
          (define eligible-cand-names (map (λ (cand) (candidate-name cand)) (set->list eligible-candidates)))
          (for/hash ([voter eligible-voters])
            (define recv-vote-chan (make-channel))
            (thread (thunk (channel-put (voter-voting-chan voter) (request-vote eligible-cand-names recv-vote-chan))))
            (values (voter-name voter) recv-vote-chan)))
                
        (log-caucus-evt "The Vote Leader in region ~a is beginning a new round of voting!" region)
        (define eligible-candidates (receive-candidates candidate-blacklist))
        (define eligible-voters (receive-voters voter-blacklist))
        (define voting-chan-table (issue-votes eligible-voters eligible-candidates))
        (collect-votes eligible-voters voter-blacklist voting-chan-table eligible-candidates candidate-blacklist))


      ;; Determine winner of a round of voting or eliminate a candidate and move to the next one
      ;; (Setof Voter) (Setof Name) (Hashof Name -> Chan) (Setof Candidate) (Setof Name) -> Candidate
      (define (collect-votes voters voter-blacklist voting-chan-table candidates candidate-blacklist)
        (define VOTE-DEADLINE (+ (current-inexact-milliseconds) 500))

        ;; NOTE move this to just above the match?
        (define vote-timeout (alarm-evt VOTE-DEADLINE))

        (define (create-voter-lookup voters)
          (for/hash ([voter voters]) (values (voter-name voter) voter)))

        (define voter-lookup (create-voter-lookup voters))


        (let voting-loop ([voter-blacklist voter-blacklist]
                          [voting-record (hash)])

          ;; Determine winner if one candidate has received majority of votes, otherwise begin next round of voting
          ;; (Hashof Name -> Voter) (Hashof Name -> Name) (Hashof Name -> number) -> candidate msg to vote leader
          (define (count-votes voter-blacklist voting-record)
            (define votes (foldl (λ (vote acc) (hash-update acc (cdr vote) add1 0)) (hash) (hash->list voting-record)))
            (define front-runner (argmax (λ (cand) (hash-ref votes (candidate-name cand) 0)) (set->list candidates)))
            (define their-votes (hash-ref votes (candidate-name front-runner) 0))
            (cond
              [(> their-votes (/ (hash-count voting-record) 2))
               (log-caucus-evt "Candidate ~a has been elected in region ~a!" (candidate-name front-runner) region)
               front-runner]
              [else (next-round voter-blacklist voting-record votes)]))

          ;; Remove the worst-performing candidate from the race and re-run caucus
          ;; (Hashof Name -> Voter) (Hashof Name -> Name) (Hashof Name -> number) -> candidate msg to vote leader
          (define (next-round voter-blacklist voting-record votes)
            (define losing-cand (argmin (λ (cand) (hash-ref votes (candidate-name cand) 0)) (set->list candidates)))
            (for ([cand-struct candidates]) 
              (channel-put (candidate-results-chan cand-struct) (ballot-results votes)))
            (channel-put (candidate-results-chan losing-cand) (loser (candidate-name losing-cand)))

            (log-caucus-evt "Candidate ~a has been eliminated from the race in region ~a!" (candidate-name losing-cand) region)
            (run-caucus (set-add candidate-blacklist (candidate-name losing-cand)) voter-blacklist))

          ;; Determine if all votes for the round have concluded
          ;; (Hashof Name -> Voter) (Hashof Name -> Name) (Hashof Name -> number) -> candidate msg to vote leader
          (define (conclude-vote? voter-blacklist voting-record)
            (if (= (hash-count voting-record) (set-count (filter-voters (set->list voters) voter-blacklist)))
              (count-votes voter-blacklist voting-record)
              (voting-loop voter-blacklist voting-record)))

          (define (try-cast-vote name candidate voter-blacklist voting-record)
            (cond
              [(set-member? voter-blacklist name)
               (log-caucus-evt "Invalid voter ~a has tried to vote in region ~a!" name region)
               (values voter-blacklist voting-record)]
              [(hash-has-key? voting-record name)
               (log-caucus-evt "Voter ~a has already voted! ~a is no longer a valid voter!" name name)
               (values (set-add voter-blacklist name) (hash-remove voting-record name))]
              [(andmap (λ (cand) (not (string=? candidate (candidate-name cand)))) (set->list candidates))
               (log-caucus-evt "Voter ~a voted for candidate ~a, who isn't currently an eligible candidate in region ~a!" name candidate region)
               (values (set-add voter-blacklist name) voting-record)]
              [else
                (log-caucus-evt "Voter ~a in region ~a has successfully voted for candidate ~a!" name region candidate)
                (values voter-blacklist (hash-set voting-record name candidate))]))

          (define handle-vote
            (match-lambda
              [(vote name candidate)
               (try-cast-vote name candidate voter-blacklist voting-record)]))

          (define vote-events
            (apply
              choice-evt 
              (map 
                (λ (recv-vote-chan) 
                   (handle-evt recv-vote-chan 
                               (λ (vote)
                                  (define-values (new-voter-blacklist new-voting-record) (handle-vote vote))
                                  (conclude-vote? new-voter-blacklist new-voting-record))))
                (hash-values voting-chan-table))))

          (sync 
            vote-events
            (handle-evt
              vote-timeout
              (λ (_)
                 (log-caucus-evt "Round of voting in region ~a is over!" region)
                 (define-values (new-blacklist new-voting-record)
                   (for/fold ([voter-blacklist voter-blacklist]
                              [voting-record voting-record])
                             ([(voter-name voting-chan) (in-hash voting-chan-table)])
                    (cond
                      [(hash-has-key? voting-record voter-name)
                        (values voter-blacklist voting-record)]
                      [else
                        (define vote-attempt (channel-try-get voting-chan))
                        (cond
                          [vote-attempt (handle-vote vote-attempt)]
                          [else
                            (values (set-add voter-blacklist voter-name) (hash-remove voting-record voter-name))])])))
                 (count-votes new-blacklist new-voting-record))))))
        
      (define winner (run-caucus (set) (set)))
      (log-caucus-evt "We have a winner ~a in region ~a!" (candidate-name winner) region)
      (channel-put results-chan (declare-winner (candidate-name winner))))))

;; remove declaration behavior
;; add a list of regions as an argument to the region-manager
;; remove the declaration behavior in the vote leader, just the results behavior

;; Create a region-manager thread and channel
;; Chan -> winner announcement
(define (make-region-manager regions candidate-registry voter-registries main-chan)
  (define results-chan (make-channel))
  (thread
    (thunk
      (for ([region regions]
            [registry voter-registries])
        (make-vote-leader region candidate-registry registry results-chan))
      (let loop ([caucus-results (hash)])
        (define region-winner (channel-get results-chan))
        (match region-winner
          [(declare-winner candidate)
           (define new-results (hash-update caucus-results candidate add1 0))
           (define num-winners (for/sum ([num-of-votes (in-hash-values new-results)]) num-of-votes))
           (cond
             [(= num-winners (length regions))
              (define most-votes (cdr (argmax (λ (pair) (cdr pair)) (hash->list new-results))))
              (define front-runners (filter (λ (pair) (= most-votes (cdr pair))) (hash->list new-results)))
              (define front-runner-names (map (λ (cand) (car cand)) front-runners))
              (log-caucus-evt "The candidates with the most votes across the regions are ~a!" front-runner-names)
              (channel-put main-chan front-runner-names)]
             [else (loop new-results)])])))))

;; A subscriber used to print information for testing
(define (make-dummy-subscriber pub-sub-chan)
  (define updates (make-channel))
  (thread
    (thunk
      (channel-put pub-sub-chan (subscribe updates))
      (let loop ()
        (sync
          (handle-evt
            updates
            (λ (evt) (printf "Dummy Subscription: ~a\n" evt) (loop))))))))

;; a receiver used to print information from message-based conversations for testing
(define (make-dummy-receiver message-chan)
  (define messages (make-channel))
  (thread
    (thunk
      (channel-put message-chan (request-msg messages))
      (let loop ()
        (sync
          (handle-evt
          messages
          (λ (evt) (printf "Dummy Message: ~a\n" evt) (loop))))))))

;; Return a function that sorts a Listof Name by putting a specified number of Names at the front of the list
;; (Listof Name) -> ((Listof Name) -> (Listof Name))
(define (stupid-sort . cand-names)
  (define (compare-names first-cand second-cand) (string<? (candidate-name first-cand) (candidate-name second-cand)))

  (λ (candidates)
     (foldr 
       (λ (cand-name cands)
          (define candidate? (findf (λ (cand) (string=? cand-name (candidate-name cand))) cands))
          (if candidate?
            (cons candidate? (remove candidate? cands))
            cands))
       (sort candidates compare-names)
       cand-names)))

