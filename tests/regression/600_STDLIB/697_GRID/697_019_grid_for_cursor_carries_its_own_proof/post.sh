#!/bin/bash
# Pin: a grid:for cursor is trusted only on the grid it was proven for —
# minted as `__koru_gi_<grid>_L<line>` — while every other index keeps the
# floor, and the range check is emitted ONCE before the loop.
set -e

# 1. The bare cursor on the PROVEN grid never crosses the floor.
if grep -qE "__koru_at\(__koru_gi_cells_L[0-9]+\)" output_emitted.zig; then
    echo "FAIL: cursor on its own grid still routed through __koru_at"
    exit 1
fi

# 2. Trusted spelling on the proven grid (read in a value position and the
#    write lvalue).
grep -qE "__koru_intcast\(usize, main_module\.__KoruGridT_cells\.__koru_wide\(__koru_gi_cells_L[0-9]+\)\)" output_emitted.zig || {
    echo "FAIL: trusted cursor spelling not found on a proven-grid access"
    exit 1
}
grep -qE "__koru_intcast\(usize, main_module\.__KoruGridT_cells\.__koru_wide\(__koru_gwx" output_emitted.zig || {
    echo "FAIL: cursor-addressed write on the proven grid still carries the floor"
    exit 1
}

# 3. `cells[i+1]` is not the bare cursor — the floor stays.
grep -qE "__koru_at\(__koru_gi_cells_L[0-9]+ \+ 1\)" output_emitted.zig || {
    echo "FAIL: an unproven offset index lost the floor"
    exit 1
}

# 4. `dst[i]` writes to a grid the proof does not name — floor stays.
grep -q "__koru_at(__koru_gwx" output_emitted.zig || {
    echo "FAIL: a write to a grid outside the proof went unchecked"
    exit 1
}

# 5. An ordinary `for` index keeps the floor — trusted is the cursor's
#    provenance, not a property of counting.
grep -q "__koru_at(k)" output_emitted.zig || {
    echo "FAIL: unproven index lost the floor — trusted widened beyond the cursor"
    exit 1
}

# 6. The door check: one compare before the loop, panic on the outside.
grep -qE "if \(__koru_forlo_L[0-9]+ < 0 or __koru_forhi_L[0-9]+ > @as\(i64, @intCast\(main_module\.__KoruGridT_cells\.__koru_size\)\) or __koru_forlo_L[0-9]+ > __koru_forhi_L[0-9]+\) @panic" output_emitted.zig || {
    echo "FAIL: the hoisted range check is missing from the emitted driver"
    exit 1
}
