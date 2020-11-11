#lang syndicate/actor

(require json)
(require "caucus.rkt")
(require/activate syndicate/drivers/timestate)

(define test-input "example_test.json")

(define test (read-json (open-input-file test-input)))

(for ([candidate (in-list (hash-ref test 'candidates))])
  ;; TODO break this into helper functions
  (spawn-candidate (hash-ref candidate 'name)
                   (hash-ref candidate 'tax_rate)
                   (hash-ref candidate 'threshold)))

(for ([region (in-list (hash-ref test 'regions))])
  (define region-name (hash-ref region 'name))
  (for ([voter (in-list (hash-ref region 'voters))])
    ;; TODO break this into helper functions
    (spawn-voter (hash-ref voter 'name)
                 region-name
                 (stupid-sort (hash-ref (hash-ref voter 'voting_method) 'candidate)))))

(spawn-manager (map (λ (region) (hash-ref region 'name)) (hash-ref test 'regions)))

(spawn-test-output-collector "syndicate_output.json")
