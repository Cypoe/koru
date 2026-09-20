#!/bin/bash
# Emitted-shape oracle for counted-for bulk append. `marks` is
# observation-free (no handles, watch, rules, lifecycle, or armed
# insert), so its `for(0..5) ! each i |> insert` lowers to a hoisted
# capacity check + `col[base + j]` writes + one `len += n` — and the
# per-row insert event is never CALLED (its proc still emits; the site
# transformed before the rewrite consumed the arm). `kept` binds
# `| row k`, so it keeps handles AND stays per-row: the
# `__store_inserth_kept` call must still sit inside a per-item `for`.
set -u
if [ ! -f output_emitted.zig ]; then
    echo "FAIL: no output_emitted.zig"
    exit 1
fi

# --- the bulk block is there, in the probed shape ---
if ! grep -q '__koru_bulk_base = __koru_store_marks.len' output_emitted.zig; then
    echo "FAIL: no bulk base captured for marks"
    exit 1
fi
if ! grep -q 'for (0..__koru_bulk_n)' output_emitted.zig; then
    echo "FAIL: no bulk counted loop emitted"
    exit 1
fi
if ! grep -q '__koru_store_marks.on\[__koru_bulk_base + __koru_bulk_j\]' output_emitted.zig; then
    echo "FAIL: no indexed column write at base + j"
    exit 1
fi
if ! grep -q '__koru_store_marks.len += __koru_bulk_n' output_emitted.zig; then
    echo "FAIL: no single len += n after the loop"
    exit 1
fi
if ! grep -q '__koru_bulk_n > 8 - __koru_store_marks.len' output_emitted.zig; then
    echo "FAIL: capacity check was not hoisted out of the loop"
    exit 1
fi

# --- the per-row insert event is dead code: emitted, never called ---
if grep -q '__store_insert_marks_event.handler(' output_emitted.zig; then
    echo "FAIL: marks insert still called per row"
    exit 1
fi

# --- the done arm's body still runs, once, after the fill ---
if ! grep -q '__store_write_notes_event.handler' output_emitted.zig; then
    echo "FAIL: done arm body dropped — the continue splice did not fire"
    exit 1
fi

# --- kept declined: per-row handle-returning insert inside the loop ---
if ! grep -q '__store_inserth_kept_event.handler(' output_emitted.zig; then
    echo "FAIL: kept lost its per-row handle insert"
    exit 1
fi
KEPT_LOOP=$(awk '/FLOW: .*for\(\)$/,/^    }$/' output_emitted.zig | grep -c 'inserth_kept')
if [ "$KEPT_LOOP" -lt 1 ]; then
    echo "FAIL: kept's insert is not inside a for flow"
    exit 1
fi

# --- JS target: never bulk — the event call stays per row ---
if [ -f output_emitted.js ]; then
    if grep -q '__koru_bulk' output_emitted.js; then
        echo "FAIL: JS lane emitted bulk append text"
        exit 1
    fi
    if ! grep -q '__store_insert_marks_event.handler' output_emitted.js; then
        echo "FAIL: JS lost the per-row insert call for marks"
        exit 1
    fi
fi

echo "PASS: counted-for insert lowers to bulk append; observed store stays per-row"
exit 0
