# 690_340 — guarded watch on a plural store fans out

A watch guarded on another store's field (`when board.alarm == 1`) becomes
a foreign guard on the GUARD store: every `board.alarm` write re-fires the
watch. On a singleton target that is one `__store_announce_<T>(field)` call
(690_013). On a plural target the announce event takes `(row, field)` and
the foreign write names no row — so the write arm instead calls a
synthesized `__store_announce_each_<T>(field)` event that loops the live
rows and calls the target's own announce per row.

Pinned here: two live rows, three guard writes — the `alarm: 0` write
re-fires and the watch condition suppresses it, so each `alarm: 1` emits
both posts in row order and nothing else.

Both targets (`zig`, `js`) — the sweep body is per-target proc text.
