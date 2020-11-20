#lang syndicate/actor

;; NOTE types are defined in `test_harness.md`

(require json)
(require [only-in racket/cmdline command-line])
(require "caucus.rkt")
(require "../test_runner.rkt")

(require/activate syndicate/drivers/timestate)

(define INPUT-FILE "../example_test.json")
(define OUTPUT-FILE "../syndicate_output.json")

(define (create-candidate jscand)
  (spawn-candidate (hash-ref jscand 'name)
                   (hash-ref jscand 'tax_rate)
                   (hash-ref jscand 'threshold)))

(define (create-voter jsvoter region-name)
  (spawn-voter (hash-ref jsvoter 'name)
               region-name
               (stupid-sort (hash-ref (hash-ref jsvoter 'voting_method)
                                      'candidate))))

(define-values (input-file output-file)
  (command-line #:args (i o) (values i o)))

(initialize-test input-file
                 output-file
                 create-candidate
                 create-voter
                 spawn-manager
                 spawn-test-output-collector)