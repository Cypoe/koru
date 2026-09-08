#!/bin/bash
# Today's analysis is program-wide: an unrelated take forces the tolerant
# while on the later query. When per-arm scope lands, this pin dies and
# 690_301 goes green.
set -u
if [ ! -f output_emitted.zig ]; then
    echo "FAIL: no output_emitted.zig"
    exit 1
fi
if ! grep -q 'while (__koru_i < __koru_store_arena.len)' output_emitted.zig; then
    echo "FAIL: expected today's program-wide take-scan to emit the tolerant while"
    echo "  (an unrelated take anywhere on the store forces while on every query)"
    exit 1
fi
echo "PASS: unrelated take still forces the tolerant while (today's analysis)"
exit 0
