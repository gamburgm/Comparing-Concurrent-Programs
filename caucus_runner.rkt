#lang syndicate/actor

;; NOTE types are defined in `test_harness.md`

(require json)
(require "caucus.rkt")
(require/activate syndicate/drivers/timestate)

(define (create-candidate jscand)
  (spawn-candidate (hash-ref jscand 'name)
                   (hash-ref jscand 'tax_rate)
                   (hash-ref jscand 'threshold)))

(define (create-voter jsvoter region-name)
  (spawn-voter (hash-ref voter 'name)
               region-name
               (stupid-sort (hash-ref (hash-ref voter 'voting_method) 'candidate))))

(define (create-manager 


  (spawn-manager (map (λ (region) (hash-ref region 'name)) (hash-ref test 'regions)))

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
