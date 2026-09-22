#!/bin/bash
# Emitted-code oracle: the `for ! each |> insert` on the indexed store
# must take the bulk lowering AND maintain the bucket map inside the fill
# loop — the failure mode being pinned is a batch that writes columns raw
# while leaving every row it added invisible to `__index_key`.
set -u
if [ ! -f output_emitted.zig ]; then
    echo "FAIL: no output_emitted.zig"
    exit 1
fi
if ! grep -q '__koru_bulk_frem' output_emitted.zig; then
    echo "FAIL: bulk lowering did not fire on the indexed store"
    exit 1
fi
if ! grep -q '__index_key: @import' output_emitted.zig; then
    echo "FAIL: std/indexes:store(players, key) emitted no __index_key map"
    exit 1
fi
if ! grep -q '__index_key.getOrPut(koru_allocator(), __koru_ik)' output_emitted.zig; then
    echo "FAIL: the bulk loop does not maintain the bucket"
    exit 1
fi
if ! grep -q '__koru_im.?\.append' output_emitted.zig; then
    echo "FAIL: the bulk loop has no memoized bucket append"
    exit 1
fi
echo "PASS: indexed store bulk-lowers with per-row bucket maintenance"
exit 0
