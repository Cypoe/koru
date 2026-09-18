#!/bin/bash
# Pin: combining recursion must NOT emit flat continuation segments —
# the selection boundary holds in both directions. A future change that
# widens the gate to swallow this shape must go red here.
set -e
for sym in __koru_seg_eval __koru_seg_k0 __koru_cstk; do
    if grep -q "$sym" output_emitted.zig; then
        echo "FAIL: $sym emitted — combining recursion took the flat path (should stay native)"
        exit 1
    fi
done
