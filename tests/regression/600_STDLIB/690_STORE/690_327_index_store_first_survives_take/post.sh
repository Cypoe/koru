#!/bin/bash
# Emitted-code oracle: the index must be REAL, not a scan wearing the
# declaration (the honesty gap this test's TODO named). An `std/indexes`
# store emits a key→member-bucket map; `! first` on the indexed column
# emits a bucket get + a per-member row resolve (dead members — taken
# rows, never ejected — resolve to no row and are skipped); insert
# appends; the predicate on the NON-indexed column still emits the sweep.
set -u
if [ ! -f output_emitted.zig ]; then
    echo "FAIL: no output_emitted.zig"
    exit 1
fi
if ! grep -q '__index_key' output_emitted.zig; then
    echo "FAIL: std/indexes:store(players, key) emitted no __index_key map"
    exit 1
fi
if ! grep -q '__index_key.get(30)' output_emitted.zig; then
    echo "FAIL: '! first p when p.key == 30' did not route to the bucket"
    exit 1
fi
if ! grep -q '__index_key.get(20)' output_emitted.zig; then
    echo "FAIL: '! first p when p.key == 20' did not route to the bucket"
    exit 1
fi
if ! grep -q '__koru_row_of(__koru_bh)' output_emitted.zig; then
    echo "FAIL: routed lookups do not resolve members - a taken key would answer"
    exit 1
fi
if ! grep -q 'for (0..main_module.__koru_store_players.len)' output_emitted.zig; then
    echo "FAIL: the non-indexed predicate (p.val) lost its scan"
    exit 1
fi
echo "PASS: declared index emits a real bucket map, resolved lookups, and the unindexed scan survives"
exit 0
