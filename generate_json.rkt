#lang racket

(require [only-in json write-json])

(provide round-info round-loser round-winner record-json-output results->jsexpr write-results-to-file)

;; a Name is a String

;; a RoundInfo is a (round-info Region [Set-of Name] [Set-of Name] [Hash-of Name Number] (U RoundLoser RoundWinner))
(struct round-info (region voters cands tally result) #:transparent)

;; a RoundLoser is a (round-loser Name) where the name is the name of a candidate
(struct round-loser (name) #:transparent)

;; a RoundWinner is a (round-winner Name) where the name is the name of a candidate
(struct round-winner (name) #:transparent)

;; Record the jsexpr representation of the results of the election to a file
;; [Hash-of Region [List-of RoundInfo]] [Hash-of Region Name] Name String -> void
(define (record-json-output round-results region-winners winner filename)
  (define election-results (results->jsexpr round-results region-winners winner))
  (write-results-to-file election-results filename))

;; jsexpr string -> void
(define (write-results-to-file results filename)
  (with-output-to-file
    filename
    (λ () (write-json results))
    #:exists 'replace))

;; Generate a jsexpr that models the results of the election
;; [Hash-of Region [List-of RoundInfo]] [Hash-of Region Name] Name -> jsexpr
(define (results->jsexpr round-results region-winners winner)
  (define round-json-output
    ;; ASSUME every region with corresponding RoundInfo has elected a winner
    (for/list ([(region rounds) (in-hash round-results)])
      (region->jsexpr region (reverse rounds) (hash-ref region-winners region))))

  (hash 'regions round-json-output
        'winner winner))

;; Convert region information to JSExpr
;; Region [List-of RoundInfo] Name -> jsexpr
(define (region->jsexpr region round-info region-winner)
  (hash 'name region
        'rounds (map round->jsexpr round-info)
        'winner region-winner))

;; Convert round information into JSExpr
;; RoundInfo -> jsexpr
(define (round->jsexpr round-info)
  (hash
    'active_voters (sort (set->list (round-info-voters round-info)) string<?)
    'active_cands (sort (set->list (round-info-cands round-info)) string<?)
    'tally (tally->jsexpr (round-info-tally round-info))
    'result (round-result->jsexpr (round-info-result round-info))))

;; Convert a tally to jsexpr
;; [Hash-of Name Number] -> [Hash-of Symbol Number]
(define (tally->jsexpr tally)
  (for/hash ([(name vote-count) (in-hash tally)])
    (values (string->symbol name) vote-count)))

;; Convert the outcome of a round to JSExpr
;; (U RoundWinner RoundLoser) -> jsexpr
(define (round-result->jsexpr result)
  (match result
    [(round-winner winner) (hash 'type "Winner" 'candidate winner)]
    [(round-loser loser) (hash 'type "Loser" 'candidate loser)]))

