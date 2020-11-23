#lang racket

(require racket/cmdline)
(require plot/no-gui)
(require "parse_diff.rkt")

(define (tick-formatter _min _max pre-ticks)
  (for/list ([tick-val pre-ticks])
    (number->string (pre-tick-value tick-val))))

(define ((tick-layout tick-posns) _min _max)
  (for/list ([posn tick-posns])
    (pre-tick posn #t)))

(define (create-x-ticks x-axis-length)
  (define tick-posns (for/list ([tick (in-range 0 x-axis-length 50)]) tick))
  (ticks (tick-layout tick-posns) tick-formatter))

(define (create-y-ticks y-axis-length)
  (define tick-posns (for/list ([tick (in-range 0 y-axis-length 20)]) tick))
  (ticks (tick-layout tick-posns) tick-formatter))

;; NOTE string cannot be empty
(define (capitalize-string str)
  (string-append (string (char-upcase (string-ref str 0))) (substring str 1)))

(define (plot-changes lang input-file program x-max y-max)
  (define output-file (format "~a.jpeg" lang))
  
  (define graph-title (format "~a Diff Visualized" (capitalize-string lang)))

  (define change-rectangles
    (for/list ([change (in-list (parse-diff-file input-file))])
      (define start (diff-meta-line change))
      (define size (diff-meta-size change))
      (vector (ivl start (+ start 1)) (ivl 0 size))))

  (parameterize ([plot-x-tick-label-anchor 'top-right]
                 [plot-x-tick-label-angle 90]
                 [plot-x-ticks (create-x-ticks x-max)]
                 [plot-y-ticks (create-y-ticks y-max)] ;; should be max size of largest component change across the programs
                 [plot-x-far-ticks no-ticks]
                 [plot-y-far-ticks no-ticks])
    (plot-file (rectangles change-rectangles) output-file #:title graph-title #:x-label "Line of code" #:y-label "Number of lines inserted" #:x-min 1 #:x-max x-max #:y-max y-max)))

(command-line #:args (lang new-file)
  (plot-changes lang "input.txt" new-file 650 100))
