#lang racket

(require json)
(require "channel_caucus.rkt")

(define TEST-INPUT "example_test.json")
(define TEST-OUTPUT "channel_output.json")

(define main-channel (make-channel))
(define-values (candidate-registration candidate-roll) (make-abstract-registry))
(define-values (output-file-chan collect-rounds-chan collect-election-chan) (make-json-output-collector main-channel))

(define voter-registration-chans (hash))
(define voter-rolls '())

(define (create-candidate jscand)
  (make-candidate (hash-ref jscand 'name)
                  (hash-ref jscand 'tax_rate)
                  (hash-ref jscand 'threshold)
                  candidate-registration))

(define (create-voter jsvoter region)
  ;; this kinda sucks, but the only solution is to wrap this whole thing in some sort of loop...?
  (unless (hash-has-key? voter-registration-chans region)
    (define-values (voter-registration voter-roll) (make-abstract-registry))
    (set! voter-rolls (cons voter-roll voter-rolls))
    (set! voter-registration-chans (hash-set voter-registration-chans region voter-registration)))

  (make-voter (hash-ref voter 'name)
              region-name
              (stupid-sort (hash-ref (hash-ref voter 'voting_method) 'candidate))
              (hash-ref voter-registration-chans region)
              candidate-roll))

(define (create-manager regions)
  (make-region-manager regions
                       candidate-roll
                       voter-rolls
                       collect-rounds-can collect-election-chan))

(define (create-test-collector output-file)
  (channel-put 

(define run-completed (channel-get main-channel))
