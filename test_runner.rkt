#lang racket

(require json)
(provide initialize-test)

;; do we need a test-output-collector? don't think so
;; need a create-manager
;; need a create-candidate
;; need a create-voter

;; String String [JSCand -> void] [JSVoter Region -> void] 
(define (initialize-test input-file       ;; String
                         output-file      ;; String
                         create-candidate ;; [JSCand -> void]
                         create-voter     ;; [JSVoter Region -> void]
                         create-manager   ;; [[List-of Region]
                         create-test-collector)  ;; String -> void
  (define test (read-json (open-input-file input-file)))

  (for ([candidate (in-list (hash-ref test 'candidates))])
    (create-candidate candidate))

  (for ([region (in-list (hash-ref test 'regions))])
    (initialize-region region create-voter))

  (create-manager (map (λ (region) (hash-ref region 'name)) (hash-ref test 'regions)))
  (create-test-collector output-file))

;; Region [JSRegion [JSVoter -> void]] -> void
(define (initialize-region region create-voter)
  (define region-name (hash-ref region 'name))
  (for ([voter (in-list (hash-ref region 'voters))])
    (create-voter voter region-name)))
