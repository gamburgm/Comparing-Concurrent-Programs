#lang racket

(require plot/no-gui)

(define (tick-formatter _min _max pre-ticks)
  (for/list ([tick-val pre-ticks])
    (number->string (pre-tick-value tick-val))))

(define ((tick-layout tick-posns) _min _max)
  (for/list ([posn tick-posns])
    (pre-tick posn #t)))


(define (create-x-ticks x-axis-length)
  (define tick-posns (for/list ([tick (in-range 0 x-axis-length 50)]) tick))
  (ticks (tick-layout tick-posns) tick-formatter))

(define (plot-changes input-file output-file file-size)
  (define change-rectangles
    (for/list ([line (file->lines input-file)])
      (define change-info (string-split line ","))
      (define x-pos (string->number (first change-info)))
      (define y-pos (string->number (second change-info)))
      (vector (ivl x-pos (+ x-pos 1)) (ivl 0 y-pos))))

  (parameterize ([plot-x-tick-label-anchor 'top-right]
                 [plot-x-tick-label-angle  90]
                 [plot-width 350]
                 [plot-x-ticks (create-x-ticks file-size)]
                 [plot-x-far-ticks no-ticks]
                 [plot-y-far-ticks no-ticks])
    (plot-file (rectangles change-rectangles) output-file #:title "Syndicate Diff Visualized" #:x-label "Line of code" #:y-label "Number of lines inserted" #:x-min 1 #:x-max (+ file-size 1))))

(plot-changes "input.txt" "syndicate.jpeg" 323)
