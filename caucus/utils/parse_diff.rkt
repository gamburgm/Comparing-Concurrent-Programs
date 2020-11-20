#lang racket

(provide parse-diff-file (struct-out diff-meta))

;; a Diff is a (diff Number Number) representing the line number that a change begins at and the size of the change
(struct diff-meta (line size) #:transparent)

(define (parse-diff-file filename)
  (for/list ([line (file->lines filename)])
    (define change-info (string-split line ","))
    (diff-meta (string->number (first change-info))
          (string->number (second change-info)))))

