#!/bin/bash
# Emitted-code oracle: the bucket map's key type must be the column's own
# declared type — `i32` here, visible as `AutoHashMapUnmanaged(i32, ...)` —
# not a hardcoded i64; and `! query` on the i32 key must route, not sweep.
set -u
if [ ! -f output_emitted.zig ]; then
    echo "FAIL: no output_emitted.zig"
    exit 1
fi
if ! grep -q '__index_grp: @import' output_emitted.zig; then
    echo "FAIL: std/indexes:store(tags, grp) emitted no __index_grp map"
    exit 1
fi
if ! grep -q 'AutoHashMapUnmanaged(i32' output_emitted.zig; then
    echo "FAIL: the bucket map did not take the column's i32 key type"
    exit 1
fi
if ! grep -q '__index_grp.getPtr(__koru_ik)) |__koru_ib|' output_emitted.zig; then
    echo "FAIL: '! query t when t.grp == 1' did not route to the bucket"
    exit 1
fi
echo "PASS: i32-keyed index routes — map keyed on the column's declared type"
exit 0
