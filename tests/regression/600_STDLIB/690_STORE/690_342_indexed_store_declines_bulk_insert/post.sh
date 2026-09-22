#!/bin/bash
# Emitted-code oracle: the `for ! each |> insert` on the indexed store
# must stay PER-ROW — the bulk lowering writes columns raw and would add
# rows the index never sees. The pin is the absence of the bulk block's
# markers plus the per-row insert-event call still carrying `__site_line`.
set -u
if [ ! -f output_emitted.zig ]; then
    echo "FAIL: no output_emitted.zig"
    exit 1
fi
if grep -q '__koru_bulk_frem' output_emitted.zig; then
    echo "FAIL: bulk lowering fired on an indexed store - rows would bypass __index_key"
    exit 1
fi
if ! grep -q '__index_key: @import' output_emitted.zig; then
    echo "FAIL: std/indexes:store(players, key) emitted no __index_key map"
    exit 1
fi
if ! grep -q '__store_insert_players_event.handler' output_emitted.zig; then
    echo "FAIL: the per-row insert event call is gone"
    exit 1
fi
if ! grep -q '__index_key.getOrPut(koru_allocator(), __koru_ik)' output_emitted.zig; then
    echo "FAIL: the insert path no longer maintains the bucket"
    exit 1
fi
echo "PASS: indexed store declines bulk append — per-row insert maintains the bucket"
exit 0
