#!/bin/sh

./diff_meta.sh $2 $3 > input.txt
racket generate_graph.rkt $1 $3
