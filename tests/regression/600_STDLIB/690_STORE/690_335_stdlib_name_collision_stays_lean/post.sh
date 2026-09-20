#!/bin/bash
# Emitted-shape oracle for the name-collision gate fix. koru_std's own
# module bodies index locals named `items` (`.items[`, the ArrayList
# idiom), `names` (`names[i] = field.name`, store.kz), `data`
# (`data[wi]`, field.kz) and `fields` (`fields[i]`, interpreter.run) —
# text a whole-program name scan cannot distinguish from an index on a
# user store of the same name. The gate now scans only items that can
# textually name the store (non-koru_std modules plus the store's own
# home) and excludes `.name[` member access, so all four stores below
# must be lean: zero handle machinery anywhere in the file, and each
# counted fill must have lowered to bulk append.
set -u
if [ ! -f output_emitted.zig ]; then
    echo "FAIL: no output_emitted.zig"
    exit 1
fi

# --- no handle machinery at all: four stores, all observation-free ---
if grep -q 'hslot\|__koru_resolve\|__koru_handle_of\|__koru_row_of' output_emitted.zig; then
    echo "FAIL: a stdlib-named store kept handle machinery"
    exit 1
fi

# --- every counted fill lowered to bulk append ---
for s in items names data fields; do
    if ! grep -q "__koru_store_${s}.on\[__koru_bulk_base + __koru_bulk_j\]" output_emitted.zig; then
        echo "FAIL: $s fill did not bulk-lower"
        exit 1
    fi
    if ! grep -q "__koru_store_${s}.len += __koru_bulk_n" output_emitted.zig; then
        echo "FAIL: $s missing the single len += n"
        exit 1
    fi
done

# --- JS lane: correct per-row lowering, no Zig bulk text ---
if [ -f output_emitted.js ]; then
    if grep -q '__koru_bulk' output_emitted.js; then
        echo "FAIL: JS lane emitted bulk append text"
        exit 1
    fi
fi

echo "PASS: stores named like koru_std locals stay lean and bulk"
exit 0
