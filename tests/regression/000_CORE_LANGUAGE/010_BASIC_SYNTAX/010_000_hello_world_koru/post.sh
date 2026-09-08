#!/bin/bash
# Pins that a consumed print.blk does not ship its comptime engines in
# the program unit. The engines already ran; @import("ast") here is the
# corpse. backend_output_emitted.zig is the compiler — it keeps them.
set -u
if [ ! -f output_emitted.zig ]; then
    echo "FAIL: no output_emitted.zig"
    exit 1
fi
if grep -q '@import("ast")' output_emitted.zig; then
    echo "FAIL: program unit still imports ast (consumed print engines)"
    exit 1
fi
if grep -q '__printInterpolate' output_emitted.zig; then
    echo "FAIL: program unit still contains __printInterpolate"
    exit 1
fi
echo "PASS: consumed print engines excluded from program unit"
exit 0
