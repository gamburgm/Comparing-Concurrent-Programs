#!/bin/sh

diff -b --old-group-format='' --new-group-format='%dF,%dN
' --unchanged-group-format='' --changed-group-format='%dF,%dN
' $1 $2

