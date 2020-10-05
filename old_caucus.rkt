#lang syndicate/actor
(require racket/set)
(require [only-in racket argmax argmin identity first filter-not])
(require syndicate/drivers/timestate)
(require "caucus_struct.rkt")

(provide spawn-candidate spawn-stubborn-candidate spawn-voter spawn-greedy-voter spawn-stubborn-voter
         spawn-leaving-voter spawn-late-joining-voter spawn-not-registered-voter spawn-sleepy-voter
         spawn-leader spawn-manager stupid-sort)

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
    (when register? (assert (voter name region)))

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
           (assert (voter name region))))
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
(define (spawn-leader region)
  (spawn
    (printf "The Vote Leader for region ~a has joined the event!\n" region)
    (define/query-set voters (voter $name region) name)
    (define/query-set candidates (candidate $name _) name)

    ;; [Listof Name] -> Elected
    (define (run-round current-cands current-voters)
      (printf "still in the running: ~a\n" current-cands)
      (define round-id (gensym 'round))
      (react
        (field [valid-voters current-voters]
               [still-in-the-running current-cands]
               [voter-to-candidate (hash)]
               [votes (hash)])

        (define (invalidate-voter voter)
          (printf "Voter ~a in region ~a is now an invalid voter!\n" voter region)
          (when (hash-has-key? (voter-to-candidate) voter)
            (votes (hash-update (votes) (hash-ref (voter-to-candidate) voter) sub1)))
          (valid-voters (set-remove (valid-voters) voter)))

        (printf "Candidates still in the running in ~a for region ~a: ~a\n" round-id region (still-in-the-running))
        (assert (round round-id region (set->list (still-in-the-running))))

        (on (retracted (voter $name region)) 
            (when (set-member? (valid-voters) name) 
              (invalidate-voter name)))

        (on (retracted (candidate $name _))
            (printf "Candidate ~a in region ~a is now invalid!\n" name region)
            (when (set-member? (still-in-the-running) name)
              (still-in-the-running (set-remove (still-in-the-running) name))))

        (on (asserted (vote $who round-id region $for))
            ;; should the voter not be eliminated if they're not valid?
            (when (set-member? (valid-voters) who)
              (cond
                [(or (hash-has-key? (voter-to-candidate) who) 
                     (not (set-member? current-cands for))) 
                 (invalidate-voter who)]
                [else 
                  (printf "Voter ~a has voted for candidate ~a in ~a in region ~a!\n" who for round-id region)
                  (voter-to-candidate (hash-set (voter-to-candidate) who for))
                  (votes (hash-update (votes) for add1 0))])))

        (on-start
          (react
            (define one-sec-from-now (get-one-second-from-now))

            (on (asserted (later-than one-sec-from-now))
                (printf "Timeout reached on this round!\n")
                (valid-voters
                  (list->set (filter (λ (voter) (hash-has-key? (voter-to-candidate) voter)) (set->list (valid-voters))))))))

        (begin/dataflow
          (define num-voters (set-count (valid-voters)))
          (define num-voted (for/sum ([votes (in-hash-values (votes))])
                              votes))

          (when (= num-voters num-voted)
            (printf "Tallying has begun for ~a in region ~a!\n" round-id region)
            (define front-runner (argmax (lambda (n) (hash-ref (votes) n 0))
                                        (set->list (still-in-the-running))))
            (define their-votes (hash-ref (votes) front-runner 0))
            ;; ASSUME: we're OK running a final round with just a single candidate
            (cond
              [(> their-votes (/ num-voters 2))
              (printf "Candidate ~a has been elected in region ~a at round ~a!\n" front-runner region round-id)
              (stop-current-facet
                (react
                  (assert (elected front-runner region))))]
              [else
                (for ([candidate (in-set (candidates))])
                  (send! (tally candidate region (hash-ref (votes) candidate 0))))

                (define loser (argmin (lambda (n) (hash-ref (votes) n 0))
                                    (set->list (still-in-the-running))))
                (printf "The front-runner for ~a in region ~a is ~a! The loser is ~a!\n" round-id region front-runner loser)
                (define next-candidates (set-intersect (candidates) (set-remove (still-in-the-running) loser)))
                (stop-current-facet (run-round next-candidates (valid-voters)))])))))


    (define one-second-from-now (+ 1000 (current-inexact-milliseconds)))
    (on-start
      (react
        (on (asserted (later-than one-second-from-now))
            ;; ASSUME: at least one candidate and voter at this point
            (printf "The race has begun in region ~a!\n" region)
            (stop-current-facet (run-round (candidates) (voters))))))))

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
    (on-start (for ([region regions]) (spawn-leader region)))

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
