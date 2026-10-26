#!/bin/sh
# A `0[tn]` cell emits the narrowest uint for tn's extent via a per-struct
# const, the write threads the value through tn's own __koru_at (the panic
# edge lives at insertion), and tn reads through a tn-typed cell emit the
# trusted __koru_intcast — never __koru_at.
EMIT=$(ls output_emitted.zig 2>/dev/null || ls emitted.zig 2>/dev/null)
grep -q "__koru_idx_tn = @import(\"std\").math.IntFittingRange" "$EMIT" || { echo "idx type const missing"; exit 1; }
grep -q "nd: \[8\]__koru_idx_tn" "$EMIT" || { echo "idx column missing"; exit 1; }
grep -q "fc: \[256\]__koru_idx_tn" "$EMIT" || { echo "self-ref idx column missing"; exit 1; }
grep -q "__KoruGridT_tn.__koru_at" "$EMIT" || { echo "write-side bound check missing"; exit 1; }
grep -q "__koru_intcast(usize, main_module.__KoruGridT_tn.__koru_wide" "$EMIT" || { echo "certified read missing"; exit 1; }
grep -q "__KoruGridT_tn.__koru_at((&main_module.__koru_grid_que.nd)" "$EMIT" || { echo "arithmetic index lost its floor"; exit 1; }
exit 0
