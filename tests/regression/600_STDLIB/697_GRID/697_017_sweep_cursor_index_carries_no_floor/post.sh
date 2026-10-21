#!/bin/bash
# Pin: the sweep cursor is emitted TRUSTED — the widening + __koru_intcast
# spelling, never __koru_at — while an ordinary `cells[i]` under `for` in the
# same program keeps the floor.
set -e

# 1. No cursor ever goes through the floor.
if grep -q "__koru_at(__koru_gi" output_emitted.zig; then
    echo "FAIL: sweep cursor still routed through __koru_at"
    exit 1
fi

# 2. The trusted spelling (widen, then the vectorizer-safe cast) is emitted
#    for cursor reads.
grep -q "__koru_intcast(usize, main_module.__KoruGridT_cells.__koru_wide(__koru_gi" output_emitted.zig || {
    echo "FAIL: trusted cursor spelling (__koru_intcast + __koru_wide) not found on a cursor read"
    exit 1
}

# 3. A cursor-addressed write lands unchecked too — the write unit's own
#    parameter is trusted when the site's index is the cursor.
grep -q ")[[:space:]]*__koru_intcast(usize, main_module.__KoruGridT_cells.__koru_wide(__koru_gwx" output_emitted.zig \
 || grep -q "__koru_intcast(usize, main_module.__KoruGridT_cells.__koru_wide(__koru_gwx" output_emitted.zig || {
    echo "FAIL: cursor-addressed write unit still carries the floor"
    exit 1
}

# 4. The floor still exists for an index nobody proved: `cells[i]` under the
#    ordinary `for` must route through `__koru_at`.
grep -q "__koru_at(i)" output_emitted.zig || {
    echo "FAIL: unproven index lost the floor — trusted widened beyond the cursor"
    exit 1
}
