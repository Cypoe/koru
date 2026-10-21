#!/bin/bash
# Strict shape: line 1 is the exact fingerprint; every remaining line is a
# hang-up sweep invoking release on a still-held seeded-hex handle.
set -e
head -1 actual.txt | grep -qx '200 rounds: fingerprint 564 over 200'
bad=$(tail -n +2 actual.txt | grep -vxE "\[BRIDGE\] Invoked 'release' for handle 'h:Res:[0-9a-f]{6}' \[reslib\.res:opened\]" | head -1)
if [ -n "$bad" ]; then echo "unexpected line: $bad"; exit 1; fi
[ "$(tail -n +2 actual.txt | wc -l | tr -d ' ')" -eq 4 ]
