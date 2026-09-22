#!/bin/bash
# Emitted-code oracle: `! query` on the indexed column must ROUTE, not
# sweep — membership output alone cannot tell a bucket walk from a full
# store scan. The stable path (bodies that cannot disturb the bucket)
# emits a direct `for` over the member list; a body that writes the
# indexed column emits the removal-tolerant cursor walk; the
# non-indexed guard keeps the dense sweep.
set -u
if [ ! -f output_emitted.zig ]; then
    echo "FAIL: no output_emitted.zig"
    exit 1
fi
if ! grep -q '__index_key: @import' output_emitted.zig; then
    echo "FAIL: std/indexes:store(players, key) emitted no __index_key map"
    exit 1
fi
if ! grep -q '__index_key.getPtr(__koru_ik)) |__koru_ib|' output_emitted.zig; then
    echo "FAIL: '! query p when p.key == 1' did not route to the bucket"
    exit 1
fi
if ! grep -q 'for (__koru_ib.items) |__koru_bh|' output_emitted.zig; then
    echo "FAIL: the non-disturbing body lost the stable bucket walk"
    exit 1
fi
if ! grep -q '__koru_bi: usize = 0;' output_emitted.zig; then
    echo "FAIL: the indexed-column-writing body lost the survival walk"
    exit 1
fi
if ! grep -q '__koru_ib2.items\[__koru_bi\] == __koru_bh' output_emitted.zig; then
    echo "FAIL: the survival walk lost its post-body cursor re-check"
    exit 1
fi
if ! grep -q 'for (0..main_module.__koru_store_players.len)' output_emitted.zig; then
    echo "FAIL: the non-indexed guard (p.val) lost its sweep"
    exit 1
fi
echo "PASS: ! query routes to the bucket — stable walk for take bodies, survival walk for indexed-column writes, sweep preserved"
exit 0
