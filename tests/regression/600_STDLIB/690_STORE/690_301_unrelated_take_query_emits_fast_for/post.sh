#!/bin/bash
# Per-arm analysis: a query whose body does not take must emit the fast
# for, even when the same store is taken elsewhere in the program.
set -u
if [ ! -f output_emitted.zig ]; then
    echo "FAIL: no output_emitted.zig"
    exit 1
fi
if ! grep -q 'for (0..__koru_store_arena.len)' output_emitted.zig; then
    echo "FAIL: expected per-arm analysis to restore for on a query whose body does not take"
    exit 1
fi
if grep -q 'while (__koru_i < __koru_store_arena.len)' output_emitted.zig; then
    echo "FAIL: tolerant while still emitted; per-arm analysis should have dropped it"
    exit 1
fi
echo "PASS: query without a take emits the fast for"
exit 0
