#!/bin/sh

FILTER="@@ .* @@"
SED_EXP="s/^@@ \(.*\) @@$/\1/"

git diff -U0 "$@" | grep "${FILTER}" | sed -e "${SED_EXP}"
