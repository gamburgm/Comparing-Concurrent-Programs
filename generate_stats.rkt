#lang racket

(require racket/cmdline)
(require "parse_diff.rkt")

(define (change-count diffs)
  (length diffs))

(define (average-change diffs)
  (/ (for/sum ([diff diffs]) (diff-meta-size diff))
     (length diffs)))

(define (average-dist diffs)
  (/
    (for*/sum ([start-diff diffs]
               [end-diff diffs])
      (define dist (- (diff-meta-line end-diff) (diff-meta-line start-diff)))
      (if (<= dist 0) 0 dist))
    (/ (* (length diffs) (- (length diffs) 1)) 2)))

(define (calculate-stats input-file)
  (define diffs (parse-diff-file input-file))

  (printf "number of changes: ~a\n" (change-count diffs))
  (printf "average size of change: ~a\n" (average-change diffs))
  (printf "average distance between changes: ~a\n" (average-dist diffs)))

(calculate-stats "input.txt")
