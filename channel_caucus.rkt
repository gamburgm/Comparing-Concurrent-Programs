#lang racket
(require racket/set)
(require "channel_struct.rkt")

(provide make-abstract-registry make-candidate make-stubborn-candidate make-voter make-greedy-voter make-stubborn-voter make-sleepy-voter make-voter-registry make-vote-leader make-event-registry make-auditor make-region-manager stupid-sort)

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
(define (make-voter name region rank-candidates participation-registry voter-registry candidate-registry evt-registry)
  (define (normal-voting existing-candidates available-candidates leader-chan)
    (define priorities (rank-candidates (set->list existing-candidates)))
    (define voting-for
      (for/first ([candidate (in-list priorities)]
                  #:when (member (candidate-name candidate) available-candidates))
                 (candidate-name candidate)))
    (log-caucus-evt "Voter ~a has submitted a vote for candidate ~a!" name voting-for)
    (announce-vote leader-chan (vote name voting-for)))

  (voter-skeleton name region normal-voting participation-registry voter-registry candidate-registry evt-registry))

;; Make a voter thread that produces a greedy voter (who votes multiple times)
(define (make-greedy-voter name region rank-candidates participation-registry voter-registry candidate-registry evt-registry)
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

  (voter-skeleton name region greedy-voting participation-registry voter-registry candidate-registry evt-registry))

;; Make a voter thread that always votes for the same candidate
(define (make-stubborn-voter name region favorite-candidate participation-registry voter-registry candidate-registry evt-registry)
  (define (stubborn-voting existing-candidates available-candidates leader-chan)
    (log-caucus-evt "Stubborn voter ~a is voting for ~a again!" name favorite-candidate)
    (announce-vote leader-chan (vote name favorite-candidate)))

  (voter-skeleton name region stubborn-voting participation-registry voter-registry candidate-registry evt-registry))

;; Make a voter that sleeps through their vote (doesn't vote)
(define (make-sleepy-voter name region participation-registry voter-registry candidate-registry evt-registry)
  (define (sleepy-voting x y z) (log-caucus-evt "Sleepy voter ~a has slept through their vote!" name))

  (voter-skeleton name region sleepy-voting participation-registry voter-registry candidate-registry evt-registry))

;; Submit a vote to the vote leader
;; NOTE this is put in another thread to prevent deadlocks in voters
;; Chan Vote -> thread
(define (announce-vote leader-chan vote)
  (thread (thunk (channel-put leader-chan vote))))

;; Create a voter thread
;; Name Region ((Listof Candidate) (Listof Candidate) Chan -> thread w/vote) Chan Chan -> voter thread
(define (voter-skeleton name region voting-procedure voter-participation-registry voter-registry candidate-registry event-registry)
  (define receive-candidates-chan (make-channel))
  (define voting-chan (make-channel))
  (define participation-chan (make-channel))
  (thread
    (thunk
      (log-caucus-evt "Voter ~a is registering!" name)
      (channel-put candidate-registry (subscribe receive-candidates-chan))
      (channel-put voter-participation-registry (publish (voter name region voting-chan)))
      (channel-put voter-registry (register name region))
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

(define (make-voter-registry)
  (define recv-manager-chan (make-channel))
  (define registration-channel (make-channel))
  (define voter-roll-channel (make-channel))

  (define (manage-registrants deadline-time valid-regions)

    (define registration-timeout (alarm-evt deadline-time))

    (let loop ([reg-info (hash)])
      (define (registered? name) (hash-has-key? reg-info name))
      (define (valid-region? region) (set-member? valid-regions region))

      (sync
        (handle-evt
          registration-timeout
          (λ (_) 
             (define voters-per-region
               (for/fold ([voters-per-region (hash)])
                         ([(voter region) (in-hash reg-info)])
                 (hash-update voters-per-region region (λ (voters) (set-add voters voter)) (set))))

             (serve-registration-info voters-per-region)))

        (handle-evt
          registration-channel
          (λ (msg)
            (define (update-registration name region #:should-be-registered? [should-be-registered? #f])
              (if (and (valid-region? region)
                       (equal? should-be-registered? (registered? name)))
                (loop (hash-set reg-info name region))
                (loop reg-info)))

            (match msg
              [(register name region) (update-registration name region #:should-be-registered? #f)]
              [(change-reg name region) (update-registration name region #:should-be-registered? #t)]
              [(unregister name)
               (if (registered? name)
                 (loop (hash-remove reg-info name))
                 (loop reg-info))]))))))

  (define (serve-registration-info voters-per-region)
    (let loop ()
      (define voter-roll-request (channel-get voter-roll-channel))
      (match voter-roll-request
        [(voter-roll recv-chan region)
         (channel-put recv-chan (payload (hash-ref voters-per-region region (set))))
         (loop)])))

  (thread
    (thunk 
      (match (channel-get recv-manager-chan)
        [(registration-config deadline-time regions)
        (manage-registrants deadline-time (list->set regions))])))

  (values recv-manager-chan registration-channel voter-roll-channel))

(define (make-auditor region voter-registry)
  (define retrieve-voters-chan (make-channel))
  (define audit-chan (make-channel))

  (define (receive-region-roll)
    (channel-put voter-registry (voter-roll retrieve-voters-chan region))
    (define voter-payload (channel-get retrieve-voters-chan))
    (match voter-payload
      [(payload voters) voters]))
  
  (thread
    (thunk
      (define voters-in-region (receive-region-roll))

      (let loop ([participating-voters (set)]
                 [voter-blacklist (set)])

        (define (process-ballots cands votes)
          (for/fold ([audited-ballots (hash)]
                      [blacklist voter-blacklist])
                    ([vote votes])
            (match-define (ballot voter candidate) vote)
            (define audited-ballot (audit-ballot audited-ballots blacklist cands votes candidate voter))
            (values
              (hash-set audited-ballots voter audited-ballot)
              (update-blacklist blacklist voter audited-ballot))))

        (define (audit-ballot audited-ballots blacklist candidates received-votes cand voter)
          (cond
            [(not (set-member? voters-in-region voter))
             (unregistered-voter voter)]
            [(not (set-member? participating-voters voter))
             (not-participating-voter voter)]
            [(set-member? blacklist voter)
             (banned-voter voter (hash-ref audited-ballots voter))]
            [(hash-has-key? audited-ballots voter)
             (multiple-votes voter (filter (λ (b) (string=? voter (ballot-voter b))) received-votes))]
            [(not (set-member? candidates cand))
             (ineligible-cand voter cand)]
            [else (valid-vote voter cand)]))

        (define (update-blacklist blacklist voter audited-ballot)
          (if (valid-vote? voter)
            blacklist
            (set-add blacklist voter)))

        (define audit-request (channel-get audit-chan))
        (match audit-request
          [(audit-voters recv-chan voters)
           (define invalid-voters (set-subtract voters voters-in-region))
           (channel-put recv-chan (invalidated-voters invalid-voters))
           (loop voters invalid-voters)]
          [(audit-ballots recv-chan candidates votes)
           (define-values (audited-ballots new-blacklist) (process-ballots candidates votes))
           (define invalid-ballots (filter (λ (b) (not (valid-vote? b))) (hash-values audited-ballots)))
           (channel-put recv-chan (invalidated-ballots invalid-ballots))
           (loop participating-voters new-blacklist)]))))
  audit-chan)

;; Make the Vote Leader thread
;; Region Chan Chan Chan -> vote leader thread
(define (make-vote-leader region candidate-registry participation-registry auditor-chan results-chan deadline-time)
  (define retrieve-candidates-chan (make-channel))
  (define retrieve-voters-chan (make-channel))
  (define audited-voters-chan (make-channel))
  (define audited-votes-chan (make-channel))
  (define voting-chan (make-channel))

  (thread
    (thunk
      (log-caucus-evt "The Vote Leader in region ~a is ready to run the caucus!" region)

      ;; Start a sequence of votes to determine an elected candidate
      ;; (Setof Name) (Setof Name) -> Candidate
      (define (run-caucus candidate-blacklist)
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
      (define (receive-voters)
        (channel-put participation-registry (message retrieve-voters-chan))
        (define voter-payload (channel-get retrieve-voters-chan))
        (match voter-payload
          [(payload new-voters)
           (channel-put auditor-chan (audit-voters audited-voters-chan (list->set (map (λ (voter-struct) (voter-name voter-struct)) (set->list new-voters)))))
           (define audited-payload (channel-get audited-voters-chan))
           (match audited-payload
             [(invalidated-voters voter-blacklist)
              (list->set (filter-voters (set->list new-voters) voter-blacklist))])]))

        ;; Issue ballots to all eligible voters and return each voter's voting channel
        ;; (Setof Voter) (Setof Candidate) -> (Hashof Name -> Chan)
        (define (issue-votes eligible-voters eligible-candidates)
          (log-caucus-evt "Vote leader in region ~a is issuing a vote!" region)
          (define eligible-cand-names (map (λ (cand) (candidate-name cand)) (set->list eligible-candidates)))
          (for/hash ([voter eligible-voters])
            (define recv-vote-chan (make-channel))
            (thread (thunk (channel-put (voter-voting-chan voter) (request-vote eligible-cand-names recv-vote-chan))))
            (values (voter-name voter) recv-vote-chan)))

        (define eligible-candidates (receive-candidates candidate-blacklist))
        (define eligible-voters (receive-voters))
        (define voting-chan-table (issue-votes eligible-voters eligible-candidates))
        (log-caucus-evt "The Vote Leader in region ~a is beginning a new round of voting!" region)
        (collect-votes eligible-voters voting-chan-table eligible-candidates candidate-blacklist))

      ;; Determine winner of a round of voting or eliminate a candidate and move to the next one
      ;; (Setof Voter) (Setof Name) (Hashof Name -> Chan) (Setof Candidate) (Setof Name) -> Candidate
      (define (collect-votes voters voting-chan-table candidates candidate-blacklist)
        (define VOTE-DEADLINE (+ (current-inexact-milliseconds) 500))

        ;; NOTE move this to just above the match?
        (define vote-timeout (alarm-evt VOTE-DEADLINE))

        (let voting-loop ([voting-record '()])

          ;; Determine winner if one candidate has received majority of votes, otherwise begin next round of voting
          ;; (Hashof Name -> Voter) (Hashof Name -> Name) (Hashof Name -> number) -> candidate msg to vote leader
          (define (count-votes voting-record)
            (channel-put auditor-chan (audit-ballots audited-votes-chan (map candidate-name (set->list candidates)) voting-record))
            (define audit-payload (channel-get audited-votes-chan))
            (match audit-payload
              [(invalidated-ballots invalid-ballots)
               (define invalid-voters
                 (for/set ([b invalid-ballots])
                   (match b
                     [(or (unregistered-voter v)
                          (not-participating-voter v)
                          (banned-voter v _)
                          (multiple-votes v _)
                          (ineligible-cand v _))
                      v])))
               (define valid-ballots (filter (λ (b) (not (set-member? invalid-voters (ballot-voter b)))) voting-record))
               (define votes
                 (for/fold ([votes (hash)])
                           ([vote valid-ballots])
                   (match-define (ballot voter cand) vote)
                   (hash-update votes cand add1 0)))

               (define front-runner (argmax (λ (cand) (hash-ref votes (candidate-name cand) 0)) (set->list candidates)))
               (define their-votes (hash-ref votes (candidate-name front-runner) 0))
               (cond
                 [(> their-votes (/ (set-count valid-ballots) 2))
                  (log-caucus-evt "Candidate ~a has been elected in region ~a!" (candidate-name front-runner) region)
                  front-runner]
                 [else (next-round votes)])]))

          ;; Remove the worst-performing candidate from the race and re-run caucus
          ;; (Hashof Name -> Voter) (Hashof Name -> Name) (Hashof Name -> number) -> candidate msg to vote leader
          (define (next-round votes)
            (define losing-cand (argmin (λ (cand) (hash-ref votes (candidate-name cand) 0)) (set->list candidates)))
            (for ([cand-struct candidates]) 
              (channel-put (candidate-results-chan cand-struct) (ballot-results votes)))
            (channel-put (candidate-results-chan losing-cand) (loser (candidate-name losing-cand)))

            (log-caucus-evt "Candidate ~a has been eliminated from the race in region ~a!" (candidate-name losing-cand) region)
            (run-caucus (set-add candidate-blacklist (candidate-name losing-cand))))

          (define handle-vote
            (match-lambda
              [(vote name candidate)
               (cons (ballot name candidate) voting-record)]))

          (define vote-events
            (apply
              choice-evt 
              (map 
                (λ (recv-vote-chan) 
                   (handle-evt 
                     recv-vote-chan
                     (λ (vote) (voting-loop (handle-vote vote)))))
                (hash-values voting-chan-table))))

          (sync 
            vote-events
            (handle-evt
              vote-timeout
              (λ (_)
                 (log-caucus-evt "Round of voting in region ~a is over!" region)
                 (define already-voted (list->set (map ballot-voter voting-record)))
                 (define new-voting-record
                   (for/fold ([voting-record voting-record])
                             ([(voter-name voting-chan) (in-hash voting-chan-table)])
                    (cond
                      [(set-member? already-voted voter-name) voting-record]
                      [else
                        (define vote-attempt (channel-try-get voting-chan))
                        (cond
                          [vote-attempt (handle-vote vote-attempt)]
                          [else voting-record])])))
                 (count-votes new-voting-record))))))

      (define participation-timeout (alarm-evt deadline-time))
      (sync
        (handle-evt participation-timeout
          (λ (_)
            (define winner (run-caucus (set)))
            (log-caucus-evt "We have a winner ~a in region ~a!" (candidate-name winner) region)
            (channel-put results-chan (declare-winner (candidate-name winner)))))))))

(define (make-event-registry)
  (define registration-chan (make-channel))
  (define evt-info-chan (make-channel))

  (thread
    (thunk
      (let loop ([evts (hash)])
        (sync
          (handle-evt
            registration-chan
            (match-lambda
              [(register-evt evt-name evt-time)
               (loop (hash-set evts evt-name evt-time))]))
          (handle-evt
            evt-info-chan
            (match-lambda
              [(get-evt-info evt-name recv-chan)
               (channel-put recv-chan (evt-info evt-name (hash-ref evts evt-name #f)))
               (loop evts)]))))))
  (values registration-chan evt-info-chan))


;; Create a region-manager thread and channel
;; Chan -> winner announcement
(define (make-region-manager regions candidate-registry participation-registries voter-roll-chan voter-registry-chan evt-registry-chan main-chan)
  (define results-chan (make-channel))
  (thread
    (thunk
      (define curr-time (current-inexact-milliseconds))
      (define reg-deadline (+ curr-time 1000))
      (define doors-close (+ curr-time 2000))

      (channel-put evt-registry-chan (register-evt REG-DEADLINE-NAME reg-deadline))
      (channel-put evt-registry-chan (register-evt DOORS-CLOSE-NAME doors-close))

      (define registration-timeout (alarm-evt reg-deadline))

      (channel-put voter-registry-chan (registration-config reg-deadline regions))
      (sync
        (handle-evt registration-timeout
          (λ (_)
             (for ([region regions]
                   [part-registry participation-registries])
               (define auditor-chan (make-auditor region voter-roll-chan))
               (make-vote-leader region candidate-registry part-registry auditor-chan results-chan doors-close)))))

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

