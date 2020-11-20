#lang racket

(require [only-in json read-json])

(define (compare v1 v2)
  (cond
    [(and (hash? v1) (hash? v2)) (compare-hashes v1 v2)]
    [(and (list? v1) (list? v2)) (compare-lists v1 v2)]
    [else (equal-or-blow v1 v2)]))

(define (compare-hashes h1 h2)
  (if (compare-keys h1 h2)
    (for/and ([key (hash-keys h1)])
      (compare (hash-ref h1 key) (hash-ref h2 key)))
    (blow h1 h2)))

(define (compare-lists l1 l2)
  (for/and ([el1 l1]
            [el2 l2])
    (compare el1 el2)))

(define (compare-keys h1 h2)
  (equal? (sort (hash-keys h1) symbol<?)
          (sort (hash-keys h2) symbol<?)))

(define (blow v1 v2)
  (error "values don't match!\n" v1 v2))

(define (equal-or-blow v1 v2)
  (if (equal? v1 v2)
    #t
    (blow v1 v2)))

(compare (read-json (open-input-file "example_result.json"))
         (read-json (open-input-file "elixir_output.json")))
