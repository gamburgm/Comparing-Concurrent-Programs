#lang racket

(require json)

;; do we need a test-output-collector? don't think so
;; need a create-manager
;; need a create-candidate
;; need a create-voter

;; test -> void
(define (initialize-test test
                         output-file
                         create-manager
                         create-candidate
                         create-voter)
  (for ([candidate (in-list (hash-ref test 'candidates))])
    (create-candidate candidate))

  (for ([region (in-list (hash-ref test 'regions))])
    (initialize-region region create-voter))

  (create-manager (map (λ (region) (hash-ref region 'name)) (hash-ref test 'regions)))

(define (initialize-region region create-voter)
  (define region-name (hash-ref region 'name))
  (for ([voter (in-list (hash-ref region 'voters))])
    (create-voter voter region-name)))



;; candidate -> void
(define (initialize-candidate candidate)
  (spawn-candidate (hash-ref candidate 'name)
                   (hash-ref candidate 'tax_rate)
                   (hash-ref candidate 'threshold)))
