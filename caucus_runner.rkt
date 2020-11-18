#lang syndicate/actor

;; NOTE types are defined in `test_harness.md`

(require json)
(require "caucus.rkt")
(require "test_runner.rkt")

(require/activate syndicate/drivers/timestate)

(define INPUT-FILE "example_test.json")
(define OUTPUT-FILE "syndicate_output.json")

(define (create-candidate jscand)
  (spawn-candidate (hash-ref jscand 'name)
                   (hash-ref jscand 'tax_rate)
                   (hash-ref jscand 'threshold)))

(define (create-voter jsvoter region-name)
  (spawn-voter (hash-ref jsvoter 'name)
               region-name
               (stupid-sort (hash-ref (hash-ref jsvoter 'voting_method)

(initialize-test INPUT-FILE
                 OUTPUT-FILE
                 create-candidate
                 create-voter
                 spawn-manager
                 spawn-test-output-collector)
