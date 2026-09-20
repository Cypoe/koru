#!/bin/bash
# Emitted-shape oracle for the per-store handle gate. `lean` never surfaces
# a row handle (inserts discard `| row`; the sweep reads `e.hp` only), so
# its cell carries no hslot arrays, no row_of/resolve/handle_of methods,
# and no __store_take_lean unit exists. `kept` binds `| row k` and addresses
# through `kept[k]`, so its machinery must be byte-for-byte present. One
# program, both halves of the decision.
set -u
if [ ! -f output_emitted.zig ]; then
    echo "FAIL: no output_emitted.zig"
    exit 1
fi

# --- the lean cell: columns + len, nothing handle-shaped ---
LEAN_CELL=$(awk '/__KoruStoreT_lean = struct/,/^};/' output_emitted.zig)
if [ -z "$LEAN_CELL" ]; then
    echo "FAIL: no __KoruStoreT_lean cell emitted"
    exit 1
fi
if echo "$LEAN_CELL" | grep -q '__koru_hslot\|__koru_row_hslot\|__koru_brand\|__koru_row_of\|__koru_resolve\|__koru_handle_of'; then
    echo "FAIL: lean store cell still emits handle machinery"
    exit 1
fi
if ! echo "$LEAN_CELL" | grep -q 'hp:' || ! echo "$LEAN_CELL" | grep -q 'len:'; then
    echo "FAIL: lean store cell lost its columns or len"
    exit 1
fi

# --- nothing anywhere addresses lean through the handle path ---
if grep -q '__koru_store_lean\.__koru_hslot\|__koru_store_lean\.__koru_row_hslot\|__koru_store_lean\.__koru_row_of\|__koru_store_lean\.__koru_resolve\|__koru_store_lean\.__koru_handle_of' output_emitted.zig; then
    echo "FAIL: emitted code still drives handle machinery on the lean store"
    exit 1
fi
if grep -q '__store_take_lean' output_emitted.zig; then
    echo "FAIL: __store_take_lean emitted for a store that cannot take"
    exit 1
fi

# --- the kept store is untouched ---
if ! grep -q '__koru_store_kept.__koru_hslot_row\|__KoruStoreT_kept' output_emitted.zig; then
    echo "FAIL: kept store lost its handle machinery"
    exit 1
fi
if ! grep -q '__store_take_kept' output_emitted.zig; then
    echo "FAIL: __store_take_kept missing — the take must still exist"
    exit 1
fi
if ! grep -q '__koru_store_kept.__koru_handle_of\|__koru_store_kept.__koru_row_of' output_emitted.zig; then
    echo "FAIL: kept store lost its handle mint/resolve calls"
    exit 1
fi

# --- lean insert is the dense path: capacity check, writes, len++ ---
if ! grep -q '__koru_store_lean.len += 1' output_emitted.zig; then
    echo "FAIL: lean insert lost its len increment"
    exit 1
fi

# --- JS target: same decision, when emitted ---
if [ -f output_emitted.js ]; then
    if grep -q '__store_take_lean' output_emitted.js; then
        echo "FAIL: JS emitted __store_take_lean for a store that cannot take"
        exit 1
    fi
    if grep -q '__koru_store_lean\.__koru_handle_of\|__koru_store_lean\.__koru_resolve\|__koru_store_lean\.__koru_row_of' output_emitted.js; then
        echo "FAIL: JS still drives handle machinery on the lean store"
        exit 1
    fi
    if ! grep -q '__store_take_kept' output_emitted.js; then
        echo "FAIL: JS lost __store_take_kept"
        exit 1
    fi
fi

echo "PASS: lean store emits no handle machinery; taking store retains it"
exit 0
