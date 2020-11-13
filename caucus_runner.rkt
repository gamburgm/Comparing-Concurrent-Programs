#lang syndicate/actor

;; NOTE types are defined in `test_harness.md`

(require json)
(require "caucus.rkt")
(require/activate syndicate/drivers/timestate)

;; test -> void
(define (initialize-test test output-file)
  (for ([candidate (in-list (hash-ref test 'candidates))])
    (initialize-candidate candidate))

  (for ([region (in-list (hash-ref test 'regions))])
    (initialize-region region))

  (spawn-manager (map (λ (region) (hash-ref region 'name)) (hash-ref test 'regions)))
  (spawn-test-output-collector output-file))

;; candidate -> void
(define (initialize-candidate candidate)
  (spawn-candidate (hash-ref candidate 'name)
                   (hash-ref candidate 'tax_rate)
                   (hash-ref candidate 'threshold)))

;; region -> void
(define (initialize-region region)
  (define region-name (hash-ref region 'name))
  (for ([voter (in-list (hash-ref region 'voters))])
    (initialize-voter voter region-name)))

;; voter string -> void
(define (initialize-voter voter region-name)
  (spawn-voter (hash-ref voter 'name)
               region-name
               (stupid-sort (hash-ref (hash-ref voter 'voting_method) 'candidate))))

(define test-input "example_test.json")
(define test (read-json (open-input-file test-input)))

(initialize-test test "syndicate_output.json")
