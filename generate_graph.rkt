#lang racket

(require syntax/parse/define)
(require racket/cmdline)
(require plot/no-gui)

;; TODO
;; How should the CLI work?
;; 1. you should specify the label as a command-line argument
;; 2. you should specify old and new
;; 3. line numbers should be collected from here and the math calculated
;; 4. calculate the diff from the racket stuff
;; 5. spit out some numbers elsewhere

(define (tick-formatter _min _max pre-ticks)
  (for/list ([tick-val pre-ticks])
    (number->string (pre-tick-value tick-val))))

(define ((tick-layout tick-posns) _min _max)
  (for/list ([posn tick-posns])
    (pre-tick posn #t)))

(define (create-x-ticks x-axis-length)
  (define tick-posns (for/list ([tick (in-range 0 x-axis-length 50)]) tick))
  (ticks (tick-layout tick-posns) tick-formatter))

;; NOTE string cannot be empty
(define (capitalize-string str)
  (string-append (string (char-upcase (string-ref str 0))) (substring str 1)))

(define (plot-changes lang input-file program)
  (define file-size (length (file->lines program)))
  (define approx-size (* 50 (ceiling (/ file-size 50))))
  (define output-file (format "~a.jpeg" lang))
  
  (define graph-title (format "~a Diff Visualized" (capitalize-string lang)))

  (define change-rectangles
    (for/list ([line (file->lines input-file)])
      (define change-info (string-split line ","))
      (define x-pos (string->number (first change-info)))
      (define y-pos (string->number (second change-info)))
      (vector (ivl x-pos (+ x-pos 1)) (ivl 0 y-pos))))

  (parameterize ([plot-x-tick-label-anchor 'top-right]
                 [plot-x-tick-label-angle 90]
                 [plot-width approx-size]
                 [plot-x-ticks (create-x-ticks file-size)]
                 [plot-x-far-ticks no-ticks]
                 [plot-y-far-ticks no-ticks])
    (plot-file (rectangles change-rectangles) output-file #:title graph-title #:x-label "Line of code" #:y-label "Number of lines inserted" #:x-min 1 #:x-max (+ file-size 1))))

(define-values (lang new-file)
  (command-line #:args (lang new-file) (values lang new-file)))

(plot-changes lang "input.txt" new-file)
