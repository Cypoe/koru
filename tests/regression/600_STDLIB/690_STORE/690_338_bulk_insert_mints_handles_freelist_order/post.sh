#!/bin/bash
# Emitted-shape oracle for bulk insert with handles. `units` carries
# generational handles (`snap` names them via `[id]`), so its counted
# `for` fills lower to the bulk block WITH slot minting: LIFO freelist
# pops (`free[frem-1-j]`), bump-fresh for the rest, both map writes,
# and the free_len/next writeback after the loop. `tallyfill` sits below
# the `counter` rule's declaration, so it declines — the per-row insert
# call and its reactive `__site_line` gate must still be in the emit.
set -u
if [ ! -f output_emitted.zig ]; then
    echo "FAIL: no output_emitted.zig"
    exit 1
fi

# --- the bulk block mints handles: freelist-pop-then-bump ---
if ! grep -q '__koru_bulk_frem = __koru_store_units.__koru_hslot_free_len' output_emitted.zig; then
    echo "FAIL: no freelist length captured for units"
    exit 1
fi
if ! grep -q '__koru_bulk_fresh = __koru_store_units.__koru_hslot_next' output_emitted.zig; then
    echo "FAIL: no bump-alloc cursor captured for units"
    exit 1
fi
if ! grep -q '__koru_store_units.__koru_hslot_free\[__koru_bulk_frem - 1 - __koru_bulk_j\]' output_emitted.zig; then
    echo "FAIL: freelist pops are not LIFO-ordered"
    exit 1
fi
if ! grep -q '__koru_store_units.__koru_row_hslot\[__koru_bulk_base + __koru_bulk_j\] = __koru_bulk_slot' output_emitted.zig; then
    echo "FAIL: row->slot map write missing"
    exit 1
fi
if ! grep -q '__koru_store_units.__koru_hslot_row\[__koru_bulk_slot\] = __koru_bulk_base + __koru_bulk_j' output_emitted.zig; then
    echo "FAIL: slot->row map write missing"
    exit 1
fi
if ! grep -q '__koru_store_units.__koru_hslot_free_len = __koru_bulk_frem -| __koru_bulk_n' output_emitted.zig; then
    echo "FAIL: freelist writeback missing"
    exit 1
fi
if ! grep -q '__koru_store_units.__koru_hslot_next = __koru_bulk_fresh' output_emitted.zig; then
    echo "FAIL: bump-alloc writeback missing"
    exit 1
fi

# --- tallyfill declined: per-row insert call + reactive enter gate ---
if ! grep -q '__store_insert_units_event.handler(' output_emitted.zig; then
    echo "FAIL: declined site lost its per-row insert call"
    exit 1
fi
if ! grep -q 'if (__site_line >' output_emitted.zig; then
    echo "FAIL: declined site lost its reactive enter gate"
    exit 1
fi

echo "PASS: counted-for insert into a handle store bulks with exact mint order; below-rule site stays per-row"
exit 0
