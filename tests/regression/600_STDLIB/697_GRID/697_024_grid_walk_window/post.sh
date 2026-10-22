#!/bin/sh
# A walk emits a reslicing driver: two `var` cursors off the columns, a
# counted `for (0..__koru_walktrips)` whose trip count is min(len/stride) —
# the proof the body's raw s[k]/d[k] accesses lean on, in a form LLVM can
# unroll — then `s = s[(n)..]` / `d = d[(m)..]` reslices and a tail call.
# NO __koru_at anywhere on the walked columns — the borrow's contract carries.
EMIT=$(ls output_emitted.zig 2>/dev/null || ls emitted.zig 2>/dev/null)
grep -q "var s: \[\]u8 = main_module.__koru_grid_inp.b\[0..\];" "$EMIT" || { echo "src cursor missing"; exit 1; }
grep -q "var d: \[\]u8 = main_module.__koru_grid_enc.c\[0..\];" "$EMIT" || { echo "dst cursor missing"; exit 1; }
grep -q "__koru_walktrips = @min(__koru_walktrips, d.len / (3));" "$EMIT" || { echo "trip count missing"; exit 1; }
grep -q "for (0..__koru_walktrips) |_| {" "$EMIT" || { echo "counted walk loop missing"; exit 1; }
grep -q "s = s\[(2)..\];" "$EMIT" || { echo "src reslice missing"; exit 1; }
grep -q "d = d\[(3)..\];" "$EMIT" || { echo "dst reslice missing"; exit 1; }
grep -q "__grid_walktail_" "$EMIT" || { echo "tail call missing"; exit 1; }
grep -q "__koru_gs0: \[\]u8" "$EMIT" || { echo "cursor not threaded to write unit"; exit 1; }
# No floor inside the walk's own driver proc — from the cursor decls to
# `return;` there may be no __koru_at at all (other sites, like the fill
# loop's ordinary stored, keep the floor they deserve).
awk '/var s: \[\]u8 = __koru_grid_inp|var s: \[\]u8 = main_module.__koru_grid_inp/{f=1} f&&/__koru_at/{bad=1} f&&/^            return;/{f=0} END{exit bad}' "$EMIT" || { echo "walk driver still pays the floor"; exit 1; }
exit 0
