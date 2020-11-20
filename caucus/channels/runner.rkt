#lang racket

(require json)
(require "caucus.rkt")
(require "../test_runner.rkt")
(require "../generate_json.rkt")

(define main-channel (make-channel))
(define-values (candidate-registration candidate-roll) (make-abstract-registry))
(define-values (collect-rounds-chan collect-election-chan) (make-json-output-collector main-channel))

(define voter-registration-chans (hash))
(define voter-rolls '())

(define (create-candidate jscand)
  (make-candidate (hash-ref jscand 'name)
                  (hash-ref jscand 'tax_rate)
                  (hash-ref jscand 'threshold)
                  candidate-registration))

(define (create-voter jsvoter region-name)
  ;; this kinda sucks, but the only solution is to wrap this whole thing in some sort of loop...?
  (unless (hash-has-key? voter-registration-chans region-name)
    (define-values (voter-registration voter-roll) (make-abstract-registry))
    (set! voter-rolls (cons voter-roll voter-rolls))
    (set! voter-registration-chans (hash-set voter-registration-chans region-name voter-registration)))

  (make-voter (hash-ref jsvoter 'name)
              region-name
              (stupid-sort (hash-ref (hash-ref jsvoter 'voting_method) 'candidate))
              (hash-ref voter-registration-chans region-name)
              candidate-roll))

(define (create-manager region-names)
  (make-region-manager region-names
                       candidate-roll
                       voter-rolls
                       collect-rounds-chan
                       collect-election-chan))

(define (create-test-collector output-file)
  (define test-output (channel-get main-channel))
  (write-results-to-file test-output output-file))

(define-values (test-input test-ouptut)
  (command-line #:args (i o) (values i o)))

(initialize-test test-input
                 test-ouptut
                 create-candidate
                 create-voter
                 create-manager
                 create-test-collector)
