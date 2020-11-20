#lang syndicate/actor
(require racket/set)
(require [only-in racket argmax argmin identity first filter-not])
(require syndicate/drivers/timestate)
(require "caucus_struct.rkt")

(provide spawn-candidate spawn-stubborn-candidate spawn-voter spawn-greedy-voter spawn-stubborn-voter
         spawn-leaving-voter spawn-late-joining-voter spawn-not-registered-voter spawn-sleepy-voter
         spawn-leader spawn-voter-registry spawn-manager stupid-sort)

(define (get-one-second-from-now)
  (+ (current-inexact-milliseconds) 1000))

;; Name TaxRate Threshold -> Candidate
(define (spawn-candidate name tax-rate threshold)
  (spawn
    (printf "Candidate ~a has entered the race!\n" name)
    (assert (candidate name tax-rate))
    (on (message (tally name $region $vote-count))
        (when (< vote-count threshold)
          (stop-current-facet)))))

;; Name TaxRate Threshold -> Candidate
(define (spawn-stubborn-candidate name tax-rate threshold)
  (spawn
    (printf "Stubborn candidate ~a has entered the race!\n" name)
    (assert (candidate name tax-rate))
    (on (message (tally name $region $vote-count))
        (when (< vote-count threshold)
          (printf "Candidate ~a is trying to re-enter the race!\n" name)
          (stop-current-facet (spawn-stubborn-candidate name tax-rate threshold))))))

;; Assert a vote for a candidate based on a voter's preference for a list of candidates
;; [Listof Candidate] [Listof Name] [[Listof Candidate] -> [Listof Candidate]] Name ID Region -> Vote
(define (ranked-vote candidates round-candidates rank-candidates)
  (define priorities (rank-candidates (set->list candidates)))
  ;; if no match found, voting-for is #f. Assume that doesn't happen.
  (for/first ([candidate (in-list priorities)]
              #:when (member (candidate-name candidate) round-candidates))
              (candidate-name candidate)))

(define (voter-skeleton voting-procedure name region register?)
  (spawn
    (printf "Voter ~a is intending to register in region ~a!\n" name region)
    (define/query-set candidates (candidate $name $tr) (candidate name tr))

    (on (asserted (registration-open))
        (send! (register name region)))

    (when register? (assert (participating name region)))

    (during (round $id region $round-candidates)
            (voting-procedure id region round-candidates candidates))))

(define (spawn-voter name region rank-candidates)
  (define (voting-procedure id region round-candidates candidates)
       (assert (vote name id region (ranked-vote (candidates) round-candidates rank-candidates))))

  (voter-skeleton voting-procedure name region #t))

(define (spawn-greedy-voter name region first-candidate second-candidate)
    (define (voting-procedure id region round-candidates candidates)
       (if (member first-candidate round-candidates)
         (assert (vote name id region first-candidate))
         (assert (vote name id region (first round-candidates))))
       (when (member second-candidate round-candidates)
         (assert (vote name id region second-candidate))))

  (voter-skeleton voting-procedure name region #t))

(define (spawn-stubborn-voter name region invalid-candidate)
    (define (voting-procedure id region round-candidates candidates)
       (assert (vote name id region invalid-candidate)))

  (voter-skeleton voting-procedure name region #t))

(define (spawn-leaving-voter name region rank-candidates round-limit)
  (define round-count 0)
    (define (voting-procedure id region round-candidates candidates)
       (when (> round-count round-limit)
         (raise "leaving voter exit")) ;; NOTE this doesn't work
       (set! round-count (add1 round-count))
       (assert (vote name id region (ranked-vote (candidates) round-candidates rank-candidates))))

  (voter-skeleton voting-procedure name region #t))

;; Name [[Listof Candidate] -> [Listof Candidate]] Number -> Voter
(define (spawn-late-joining-voter name region rank-candidates round-limit)
  (define round-count 0)
  (define registered? #f)
    (define (voting-procedure id region round-candidates candidates)
       ;; Can also write this as the voter assertion with a #:when, but that is less clear I think
       (when (and (not registered?) (>= round-count round-limit))
         (begin
           (set! registered? #t)
           (assert (participating name region))))
       (assert #:when registered? (vote name id region (ranked-vote (candidates) round-candidates rank-candidates))))

    (voter-skeleton voting-procedure name region #f))

;; Name [[Listof Candidate] -> [Listof Candidate]] -> Voter
(define (spawn-not-registered-voter name region rank-candidates)
    (define (voting-procedure id region round-candidates candidates)
       (assert (vote name id region (ranked-vote (candidates) round-candidates rank-candidates))))

  (voter-skeleton voting-procedure name region #f))

(define (spawn-sleepy-voter name region)
  (define (voting-procedure _a _b _c _d) #f)

  (voter-skeleton voting-procedure name region #t))

;; Region -> Leader
(define (spawn-leader region participation-deadline)
  (spawn
    (printf "The Vote Leader for region ~a has joined the event!\n" region)
    (define/query-set candidates (candidate $name _) name)

    (assert (doors-opened (current-inexact-milliseconds) region))
    (assert (doors-close participation-deadline region))

    ;; [Listof Name] -> Elected
    (define (run-round current-cands current-voters)
      (printf "still in the running: ~a\n" current-cands)
      (define round-id (gensym 'round))
      (react
        (field [still-in-the-running current-cands])

        (define round-runner-id (current-facet-id))

        (printf "Candidates still in the running in ~a for region ~a: ~a\n" round-id region (still-in-the-running))
        (assert (round round-id region (set->list (still-in-the-running))))

        (on (retracted (candidate $name _))
            (printf "Candidate ~a in region ~a is now invalid!\n" name region)
            (when (set-member? (still-in-the-running) name)
              (still-in-the-running (set-remove (still-in-the-running) name))))

        (on-start
          (react
            (define/query-set have-voted (vote $who round-id region _) who)
            (define/query-set submitted-ballots (vote $who round-id region $for) (ballot who for))

            (define (end-round)
              (stop-current-facet (count-votes round-id round-runner-id (still-in-the-running) (submitted-ballots))))

            (begin/dataflow
              (when (set-empty? (set-subtract current-voters (have-voted)))
                (end-round)))

            (on-start
              (react
                (define one-sec-from-now (get-one-second-from-now))
                (on (asserted (later-than one-sec-from-now))
                    (printf "Timeout reached on this round!\n")
                    (end-round))))))))

    ;; ID [List-of Name] -> Elected
    (define (count-votes round-id round-runner-id cands ballots)
      ;; VoterStanding -> Name
      (define (get-voter-from-standing v)
        (match v
          [(voter-standing name _) name]))

      (react
        (on (asserted (audited-round round-id region $voter-standings))
          (define valid-voters
            (for/set ([standing voter-standings] #:when (clean? (voter-standing-status standing)))
                     (voter-standing-name standing)))

          (define valid-ballots
            (for/list ([b ballots] #:when (set-member? valid-voters (ballot-voter b)))
                     b))

          (define num-votes (length valid-ballots))
          (define votes
            (for/fold ([votes (hash)])
                      ([vote valid-ballots])
              (match-define (ballot voter cand) vote)
              (hash-update votes cand add1 0)))

          (printf "Tallying has begun for ~a in region ~a!\n" round-id region)
          (define front-runner (argmax (lambda (n) (hash-ref votes n 0))
                                      (set->list cands)))
          (define their-votes (hash-ref votes front-runner 0))
          ;; ASSUME: we're OK running a final round with just a single candidate
          (cond
            [(> their-votes (/ num-votes 2))
             (printf "Candidate ~a has been elected in region ~a at round ~a!\n" front-runner region round-id)
             (stop-current-facet
               (react
                 (assert (elected front-runner region))))]
            [else
             (for ([candidate (in-set (candidates))])
               (send! (tally candidate region (hash-ref votes candidate 0))))

             (define loser (argmin (lambda (n) (hash-ref votes n 0))
                                 (set->list cands)))
             (printf "The front-runner for ~a in region ~a is ~a! The loser is ~a!\n" round-id region front-runner loser)
             (define next-candidates (set-intersect (candidates) (set-remove cands loser)))
             (define valid-voter-names
               (for/set ([b valid-ballots]) (ballot-voter b)))
             (stop-current-facet (stop-facet round-runner-id (run-round next-candidates valid-voter-names)))]))))

    (define (prepare-voting candidates)
      (react
        (on (asserted (valid-voter-report region $voters))
            (stop-current-facet (run-round candidates voters)))))

    (on-start
      (react
        (on (asserted (later-than participation-deadline))
            ;; ASSUME: at least one candidate and voter at this point
            (printf "The race has begun in region ~a!\n" region)
            (stop-current-facet (prepare-voting (candidates))))))))

(define (spawn-voter-registry deadline valid-regions)
  (spawn
    (define region-lookup (list->set valid-regions))
    (field [voter-reg-status (hash)])

    (define (valid-region? region) (set-member? region-lookup region))
    (define (registered? name) (hash-has-key? (voter-reg-status) name))

    (define (update-registration name region #:should-be-registered? [should-be-registered? #f])
      (if (and (valid-region? region)
               (equal? should-be-registered? (registered? name)))
        (voter-reg-status (hash-set (voter-reg-status) name region))
        (send! (reg-fail name))))

    (assert (registration-open))

    (on (message (register $name $region))
        (update-registration name region #:should-be-registered? #f))

    (on (message (change-reg $name $region))
        (update-registration name region #:should-be-registered? #t))

    ;; TODO is there another way to abstract this?
    (on (message (unregister $name))
        (if (registered? name)
          (voter-reg-status (hash-remove (voter-reg-status) name))
          (send! (reg-fail name))))

    (on (asserted (later-than deadline))
        ;; Transform a hash from voter -> region to a hash from region -> Setof voter
        ;; Hash -> Hash
        (define (aggregate-registration-info reg-info)
          (for/fold ([voters-per-region (hash)])
                    ([(voter region) (in-hash reg-info)])
            (hash-update voters-per-region region (λ (voters) (set-add voters voter)) (set))))

        (react
          (printf "voter registry spawned\n")
          (define voters-per-region (aggregate-registration-info (voter-reg-status)))

          (during (observe (voter-roll $region _))
                  (printf "Interest in voter roll for region ~a: ~a\n" region voters-per-region)
                  (assert (voter-roll region (hash-ref voters-per-region region (set)))))))))

;; Region -> Auditor
(define (spawn-auditor region)
  (spawn

    (define (audit-voting registered-voters participating-voters)
      (react
        (field [banned-voter-record (hash)]) ;; [Hash-of Name InvalidStatus]

        (assert (valid-voter-report region participating-voters))

        (during (round $id region $round-candidates)
          (field [voter-statuses (hash)] ;; [Hash-of Name VoterStatus]
                 [received-ballots '()]) ;; [List-of Ballot]

          ;; Has this voter voted?
          ;; Name -> Boolean
          (define (already-voted? voter)
            (hash-has-key? (voter-statuses) voter))

          ;; Determine the status of a voter based on a submitted vote
          ;; Name Name -> VoterStatus
          (define (audit-ballot voter cand)
            (cond
              [(hash-has-key? (banned-voter-record) voter)
               (banned-voter (hash-ref (banned-voter-record) voter))]
              [(not (set-member? registered-voters voter)) (unregistered)]
              [(not (set-member? participating-voters voter)) (not-participating)]
              [(already-voted? voter)
               (multiple-votes (filter (λ (b) (string=? voter (ballot-voter b))) (received-ballots)))]
              [(not (set-member? round-candidates cand)) (ineligible-cand cand)]
              [else (clean)]))

          ;; Audit a ballot and update the audited ballots and blacklist accordingly
          ;; Name Name -> void
          (define (process-ballot voter cand)
            (define voter-status (audit-ballot voter cand))
            (voter-statuses (hash-set (voter-statuses) voter voter-status)))

          (during (observe (audited-round id region _))
            (define report
              (for/list ([(voter status) (in-hash (voter-statuses))])
                (voter-standing voter status)))

            (banned-voter-record
              (for/fold ([bans (banned-voter-record)])
                        ([standing (in-list report)]
                         #:unless (clean? (voter-standing-status standing)))
                (hash-set bans (voter-standing-name standing) (voter-standing-status standing))))

           (define non-voting-voters
             (for/set ([voter participating-voters]
                       #:unless (or (hash-has-key? (banned-voter-record) voter)
                                    (hash-has-key? (voter-statuses) voter)))
               voter))

            (banned-voter-record
              (for/fold ([bans (banned-voter-record)])
                        ([voter non-voting-voters])
                (hash-set bans voter (failed-to-vote))))

            (assert (audited-round id region report)))

          (on (asserted (vote $who id region $for))
              (received-ballots (cons (ballot who for) (received-ballots)))
              (process-ballot who for))

          (on (retracted (vote $who id region $for))
              (received-ballots (remove (ballot who for) (received-ballots)))
              (voter-statuses (hash-remove (voter-statuses) who))))))

    (on-start
      (react
        (define setup-id (current-facet-id))
        (field [registered-voters (set)]     ;; [Set-of Name]
               [participating-voters (set)]) ;; [Set-of name]

        (on (asserted (voter-roll region $voters))
            (registered-voters voters))

        (on (asserted (participating $name region))
            (participating-voters (set-add (participating-voters) name)))

        (on (retracted (participating $name region))
            (participating-voters (set-remove (participating-voters) name)))

        (on (asserted (observe (valid-voter-report region _)))
            (stop-facet setup-id (audit-voting (registered-voters) (set-intersect (registered-voters) (participating-voters)))))))))

;; Name -> [[Listof Candidate] -> [Listof Candidate]]
(define (stupid-sort cand-name)
  (λ (candidates)
     (define candidate? (findf (λ (cand) (string=? cand-name (candidate-name cand))) candidates))
     (if candidate?
       (cons candidate? (remove candidate? candidates))
       candidates)))

;; -> Manager
(define (spawn-manager regions)
  (spawn
    (field [caucus-results (hash)])

    (define reg-deadline (get-one-second-from-now))

    (assert (registration-deadline reg-deadline))

    (spawn-voter-registry reg-deadline regions)

    (on (asserted (later-than reg-deadline))
        (for ([region regions]) 
          (spawn-auditor region)
          (spawn-leader region (get-one-second-from-now))))

    (on (asserted (elected $name $region))
        (caucus-results (hash-update (caucus-results) name add1 0))
        ;; FIXME name
        (define num-results
          (foldl (λ (num acc) (+ acc num)) 0 (hash-values (caucus-results))))
        (when (= num-results (length regions))
          (define-values (winning-candidate _)
            (for/fold ([best-cand #f] [their-votes -1])
                      ([(cand-name cand-votes) (in-hash (caucus-results))])
              (if (< cand-votes their-votes)
                (values best-cand their-votes)
                (values cand-name cand-votes))))
          (stop-current-facet 
            (react 
              (printf "The winner of the election is ~a!\n" winning-candidate)
              (assert (outbound (winner winning-candidate)))))))))

;; Assumptions made about the manager:
;; Every elected announcement is valid
;; The manager is up and running and properly configured before voting begins (there is now 'begin voting' announcement made by the manager)
;; no leader makes multiple elected announcements

;; Candidates do actually drop per caucus. Nice.
