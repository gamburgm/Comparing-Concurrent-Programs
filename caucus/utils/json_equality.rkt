#lang racket

(require [only-in json read-json])

(define (open-as-json filename)
  (read-json (open-input-file filename)))

(command-line #:args (first-file second-file third-file)
  (let ([first-input (open-as-json first-file)]
        [second-input (open-as-json second-file)]
        [third-input (open-as-json third-file)])
    (and (equal? first-input second-input)
         (equal? second-input third-input))))
