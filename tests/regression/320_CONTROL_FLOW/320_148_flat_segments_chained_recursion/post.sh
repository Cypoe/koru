#!/bin/bash
# Pin: chained scalar recursion must emit flat continuation segments.
# The oracle (expected.txt) proves correctness; this proves the PATH —
# a future change that silently deselects flat emission must go red here,
# not just get slower.
set -e
for sym in __koru_seg_eval __koru_seg_k0 __koru_lane_w __koru_cstk; do
    grep -q "$sym" output_emitted.zig || {
        echo "FAIL: $sym not emitted — chained recursion did not take the flat segment path"
        exit 1
    }
done
