#lang racket

(require json)
(require "channel_caucus.rkt")

(define TEST-INPUT "example_test.json")
(define TEST-OUTPUT "channel_output.json")

(define test (read-json (open-input-file test-input)))

(define main-channel (make-channel))
(define-values (candidate-registration candidate-roll) (make-abstract-registry))
(define-values (collect-rounds-chan collect-election-chan) (make-json-output-collector main-channel "channel.json"))

(for ([candidate (in-list (hash-ref test 'candidates))])
  (make-candidate (hash-ref candidate 'name)
                  (hash-ref candidate 'tax_rate)
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

(make-region-manager (map (λ (region) (hash-ref region 'name)) (hash-ref test 'regions)) candidate-roll voter-rolls collect-rounds-chan collect-election-chan)

(define run-completed (channel-get main-channel))
