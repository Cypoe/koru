#!/bin/sh
# The pool rides the grid lowering path with one storage-kind flag: slice
# columns index as `(grid.f)[i]` — no `&` base pin (`*[]T` can't index) —
# while the fixed `cells` array keeps `(&grid.f)[i]`.
EMIT=$(ls output_emitted.zig 2>/dev/null || ls emitted.zig 2>/dev/null)
grep -q "(__koru_grid_ops.j)\[" "$EMIT" || grep -q "__koru_grid_ops.j)\[" "$EMIT" || { echo "pool slice index missing"; exit 1; }
grep -q "(&main_module.__koru_grid_cells.v)\[" "$EMIT" || grep -q "(&__koru_grid_cells.v)\[" "$EMIT" || { echo "array pin shape missing"; exit 1; }
grep -q "page_allocator.alloc" "$EMIT" || { echo "pool not page-backed"; exit 1; }
exit 0
