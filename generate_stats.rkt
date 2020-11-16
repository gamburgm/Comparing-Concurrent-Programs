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

(define (print-stats diffs)
  (printf "number of changes: ~a\n" (change-count diffs))
  (printf "average size of change: ~a\n" (average-change diffs))
  (printf "average distance between changes: ~a\n" (average-dist diffs)))

(define (largest-diff diffs)
  (for/fold ([curr-diff (first diffs)])
            ([new-diff (rest diffs)])
    (if (> (diff-meta-size new-diff) (diff-meta-size curr-diff))
      new-diff
      curr-diff)))

(define (calculate-stats input-file)
  (define diffs (parse-diff-file input-file))
  (define diffs-without-component (remove (largest-diff diffs) diffs))
  (print-stats diffs-without-component))

(calculate-stats "input.txt")
