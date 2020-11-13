#lang racket

(require json)
(require "channel_caucus.rkt")

(define test-input "example_test.json")

(define test (read-json (open-input-file test-input)))

(define main-channel (make-channel))
(define-values (candidate-registration candidate-roll) (make-abstract-registry))

(for ([candidate (in-list (hash-ref test 'candidates))])
  (make-candidate (hash-ref candidate 'name)
                  (hash-ref candidate 'tax-rate)
                  (hash-ref candidate 'threshold)
                  candidate-registration))

(define voter-rolls
  (for/fold ([voter-rolls '()])
            ([region (in-list (hash-ref test 'regions))])
    (define-values (voter-registration voter-roll) (make-abstract-registry))
    (define region-name (hash-ref region 'name))
    (for ([voter (in-list (hash-ref region 'voters))])
      (make-voter (hash-ref voter 'name)
                  region-name
                  (stupid-sort (hash-ref (hash-ref voter 'voting_method) 'candidate))
                  voter-registration
                  candidate-roll))
    (cons voter-roll voter-rolls)))

(make-region-manager (map (λ (region) (hash-ref region 'name)) (hash-ref test 'regions)) candidate-roll voter-rolls main-channel)

(define msg (channel-get main-channel))
(printf "We have our winners! ~a\n" msg)
