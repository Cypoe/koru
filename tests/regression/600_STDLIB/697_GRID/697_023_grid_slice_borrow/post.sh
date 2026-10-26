#!/bin/sh
# A slice borrow emits `const s = __koru_grid_g.c[0..]` next to the grid in
# the module; writes through it emit `s_arg[...] = v` in the write unit
# with the slice threaded as a []u8 argument — NO __koru_at anywhere on
# the borrowed column; reads `s[i]` splice verbatim (generic indexing).
EMIT=$(ls output_emitted.zig 2>/dev/null || ls emitted.zig 2>/dev/null)
grep -q "const s = __koru_grid_g.c\[0..\];" "$EMIT" || { echo "slice borrow const missing"; exit 1; }
grep -q "__koru_gs0: \[\]u8" "$EMIT" || { echo "slice not threaded as arg"; exit 1; }
grep -qE "__koru_gs[0-9]+\[@as\(usize" "$EMIT" || { echo "bare slice store missing"; exit 1; }
! grep -q "koru_grid_g.c\[.*at(" "$EMIT" || { echo "borrowed access still pays the floor"; exit 1; }
exit 0
