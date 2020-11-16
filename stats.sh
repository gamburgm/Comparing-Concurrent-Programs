#!/usr/bin/env bash

./diff_meta.sh $1 $2 > input.txt
racket generate_stats.rkt

