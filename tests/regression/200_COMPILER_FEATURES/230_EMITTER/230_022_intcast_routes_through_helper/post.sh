#!/bin/bash
# Pin: both cast spellings must lower through __koru_intcast — bare @intCast
# inside a loop body carries an llvm.assume that declines vectorization.
# The helper itself must also be emitted into the preamble.
set -e
grep -q "fn __koru_intcast" output_emitted.zig || {
    echo "FAIL: __koru_intcast helper not emitted in preamble"
    exit 1
}
grep -q "__koru_intcast(i64," output_emitted.zig || {
    echo "FAIL: @as(i64, @intCast(...)) did not lower through __koru_intcast"
    exit 1
}
grep -q "__koru_intcast(usize," output_emitted.zig || {
    echo "FAIL: index-position @intCast did not lower through __koru_intcast"
    exit 1
}
