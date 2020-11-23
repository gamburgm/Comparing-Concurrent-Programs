#lang racket
(require "caucus.rkt")

;;;;;;;;;;;; EXECUTION ;;;;;;;;;;;;
(define main-channel (make-channel))

;;;; GENERAL ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define-values (candidate-registration candidate-roll) (make-abstract-registry))

(define-values (recv-manager-chan voter-registration voter-region-roll) (make-voter-registry))

(define-values (evt-registration evt-info-chan) (make-event-registry))

(make-candidate "Bernie" 50 0 candidate-registration)
(make-candidate "Biden" 25 0 candidate-registration)
(make-candidate "Tulsi" 6 0 candidate-registration)
(make-candidate "Donkey" 1000000000000000 200 candidate-registration)
(make-candidate "Vermin Supreme" 35 0 candidate-registration)
(make-candidate "Steerpike" 0 0 candidate-registration)
(make-stubborn-candidate "ZZZ" 0 200000 candidate-registration)

;;;; Region 1 ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define-values (participation-registration-1 voter-roll-1) (make-abstract-registry))

(make-voter "XYZ" "Region1" (stupid-sort "Vermin Supreme") participation-registration-1 voter-registration candidate-roll evt-info-chan)
(make-voter "FOO" "Region1" (stupid-sort "Vermin Supreme") participation-registration-1 voter-registration candidate-roll evt-info-chan)
(make-voter "BAR" "Region1" (stupid-sort "Vermin Supreme") participation-registration-1 voter-registration candidate-roll evt-info-chan)
(make-voter "BAZ" "Region1" (stupid-sort "Vermin Supreme") participation-registration-1 voter-registration candidate-roll evt-info-chan)
(make-voter "012" "Region1" (stupid-sort "Biden") participation-registration-1 voter-registration candidate-roll evt-info-chan)
(make-voter "123" "Region1" (stupid-sort "Biden") participation-registration-1 voter-registration candidate-roll evt-info-chan)
(make-voter "234" "Region1" (stupid-sort "Biden") participation-registration-1 voter-registration candidate-roll evt-info-chan)
(make-voter "org" "Region1" (stupid-sort "Vermin Supreme") participation-registration-1 voter-registration candidate-roll evt-info-chan)

(make-greedy-voter "ABC" "Region1" (stupid-sort "Bernie" "Tulsi") participation-registration-1 voter-registration candidate-roll evt-info-chan)
(make-greedy-voter "DEF" "Region1" (stupid-sort "Bernie" "Tulsi") participation-registration-1 voter-registration candidate-roll evt-info-chan)
(make-greedy-voter "GHI" "Region1" (stupid-sort "Bernie" "Tulsi") participation-registration-1 voter-registration candidate-roll evt-info-chan)
(make-greedy-voter "JKL" "Region1" (stupid-sort "Biden" "Tulsi") participation-registration-1 voter-registration candidate-roll evt-info-chan)
(make-greedy-voter "MNO" "Region1" (stupid-sort "Biden" "Tulsi") participation-registration-1 voter-registration candidate-roll evt-info-chan)
(make-greedy-voter "PQR" "Region1" (stupid-sort "Biden" "Tulsi") participation-registration-1 voter-registration candidate-roll evt-info-chan)
(make-stubborn-voter "345" "Region1" "Tulsi" participation-registration-1 voter-registration candidate-roll evt-info-chan)
(make-stubborn-voter "456" "Region1" "ZZZ" participation-registration-1 voter-registration candidate-roll evt-info-chan)
(make-stubborn-voter "567" "Region1" "ZZZ" participation-registration-1 voter-registration candidate-roll evt-info-chan)
(make-stubborn-voter "678" "Region1" "ZZZ" participation-registration-1 voter-registration candidate-roll evt-info-chan)
(make-stubborn-voter "789" "Region1" "ZZZ" participation-registration-1 voter-registration candidate-roll evt-info-chan)
(make-stubborn-voter "457" "Region1" "ZZZ" participation-registration-1 voter-registration candidate-roll evt-info-chan)
(make-stubborn-voter "568" "Region1" "ZZZ" participation-registration-1 voter-registration candidate-roll evt-info-chan)
(make-stubborn-voter "679" "Region1" "ZZZ" participation-registration-1 voter-registration candidate-roll evt-info-chan)
(make-stubborn-voter "790" "Region1" "ZZZ" participation-registration-1 voter-registration candidate-roll evt-info-chan)

(make-sleepy-voter "0" "Region1" participation-registration-1 voter-registration candidate-roll evt-info-chan)
(make-sleepy-voter "1" "Region1" participation-registration-1 voter-registration candidate-roll evt-info-chan)
(make-sleepy-voter "2" "Region1" participation-registration-1 voter-registration candidate-roll evt-info-chan)
(make-sleepy-voter "3" "Region1" participation-registration-1 voter-registration candidate-roll evt-info-chan)
(make-sleepy-voter "4" "Region1" participation-registration-1 voter-registration candidate-roll evt-info-chan)
(make-sleepy-voter "5" "Region1" participation-registration-1 voter-registration candidate-roll evt-info-chan)
(make-sleepy-voter "6" "Region1" participation-registration-1 voter-registration candidate-roll evt-info-chan)
(make-sleepy-voter "7" "Region1" participation-registration-1 voter-registration candidate-roll evt-info-chan)
(make-sleepy-voter "8" "Region1" participation-registration-1 voter-registration candidate-roll evt-info-chan)
(make-sleepy-voter "9" "Region1" participation-registration-1 voter-registration candidate-roll evt-info-chan)


;;;; Region 2 ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define-values (participation-registration-2 voter-roll-2) (make-abstract-registry))

(make-voter "999" "Region2" (stupid-sort "Steerpike") participation-registration-2 voter-registration candidate-roll evt-info-chan)
(make-voter "998" "Region2" (stupid-sort "Steerpike") participation-registration-2 voter-registration candidate-roll evt-info-chan)
(make-voter "997" "Region2" (stupid-sort "Steerpike") participation-registration-2 voter-registration candidate-roll evt-info-chan)
(make-voter "996" "Region2" (stupid-sort "Steerpike") participation-registration-2 voter-registration candidate-roll evt-info-chan)
(make-voter "995" "Region2" (stupid-sort "Steerpike") participation-registration-2 voter-registration candidate-roll evt-info-chan)
(make-voter "994" "Region2" (stupid-sort "Steerpike") participation-registration-2 voter-registration candidate-roll evt-info-chan)
(make-voter "993" "Region2" (stupid-sort "Steerpike") participation-registration-2 voter-registration candidate-roll evt-info-chan)
(make-voter "992" "Region2" (stupid-sort "Steerpike") participation-registration-2 voter-registration candidate-roll evt-info-chan)
(make-voter "991" "Region2" (stupid-sort "Steerpike") participation-registration-2 voter-registration candidate-roll evt-info-chan)
(make-voter "990" "Region2" (stupid-sort "Steerpike") participation-registration-2 voter-registration candidate-roll evt-info-chan)
(make-voter "989" "Region2" (stupid-sort "Donkey") participation-registration-2 voter-registration candidate-roll evt-info-chan)
(make-voter "988" "Region2" (stupid-sort "Donkey") participation-registration-2 voter-registration candidate-roll evt-info-chan)
(make-voter "987" "Region2" (stupid-sort "Donkey") participation-registration-2 voter-registration candidate-roll evt-info-chan)
(make-voter "986" "Region2" (stupid-sort "Donkey") participation-registration-2 voter-registration candidate-roll evt-info-chan)
(make-voter "985" "Region2" (stupid-sort "Donkey") participation-registration-2 voter-registration candidate-roll evt-info-chan)
(make-voter "984" "Region2" (stupid-sort "Donkey") participation-registration-2 voter-registration candidate-roll evt-info-chan)
(make-voter "983" "Region2" (stupid-sort "Donkey") participation-registration-2 voter-registration candidate-roll evt-info-chan)

;;;; Region 3 ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define-values (participation-registration-3 voter-roll-3) (make-abstract-registry))
(make-voter "999" "Region3" (stupid-sort "Steerpike") participation-registration-3 voter-registration candidate-roll evt-info-chan)
(make-voter "998" "Region3" (stupid-sort "Steerpike") participation-registration-3 voter-registration candidate-roll evt-info-chan)
(make-voter "997" "Region3" (stupid-sort "Steerpike") participation-registration-3 voter-registration candidate-roll evt-info-chan)
(make-voter "996" "Region3" (stupid-sort "Steerpike") participation-registration-3 voter-registration candidate-roll evt-info-chan)
(make-voter "995" "Region3" (stupid-sort "Steerpike") participation-registration-3 voter-registration candidate-roll evt-info-chan)
(make-voter "994" "Region3" (stupid-sort "Steerpike") participation-registration-3 voter-registration candidate-roll evt-info-chan)
(make-voter "993" "Region3" (stupid-sort "Steerpike") participation-registration-3 voter-registration candidate-roll evt-info-chan)
(make-voter "992" "Region3" (stupid-sort "Steerpike") participation-registration-3 voter-registration candidate-roll evt-info-chan)
(make-voter "991" "Region3" (stupid-sort "Steerpike") participation-registration-3 voter-registration candidate-roll evt-info-chan)
(make-voter "990" "Region3" (stupid-sort "Steerpike") participation-registration-3 voter-registration candidate-roll evt-info-chan)
(make-voter "989" "Region3" (stupid-sort "Donkey") participation-registration-3 voter-registration candidate-roll evt-info-chan)
(make-voter "988" "Region3" (stupid-sort "Donkey") participation-registration-3 voter-registration candidate-roll evt-info-chan)
(make-voter "987" "Region3" (stupid-sort "Donkey") participation-registration-3 voter-registration candidate-roll evt-info-chan)
(make-voter "986" "Region3" (stupid-sort "Donkey") participation-registration-3 voter-registration candidate-roll evt-info-chan)
(make-voter "985" "Region3" (stupid-sort "Donkey") participation-registration-3 voter-registration candidate-roll evt-info-chan)
(make-voter "984" "Region3" (stupid-sort "Donkey") participation-registration-3 voter-registration candidate-roll evt-info-chan)
(make-voter "983" "Region3" (stupid-sort "Donkey") participation-registration-3 voter-registration candidate-roll evt-info-chan)

;; TODO wtf is the 'recv-manager-chan'
(make-region-manager (list "Region1" "Region2" "Region3") candidate-roll (list voter-roll-1 voter-roll-2 voter-roll-3) voter-region-roll recv-manager-chan evt-registration main-channel)

(define msg (channel-get main-channel))
(printf "We have our winners! ~a\n" msg)
