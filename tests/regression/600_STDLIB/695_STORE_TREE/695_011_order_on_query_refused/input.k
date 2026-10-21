// 695_011 — `order:` on a flat `query` site is refused, not dropped. A plain
// sweep has no levels to order; the diagnostic points at preorder rather than
// silently emitting an unordered walk.
import std/io
import std/store

std/store:new(pool, capacity: 64) { hp: i64 }

std/store:insert(pool) { hp: 5 }

std/store:query(pool, order: "hp")
! query e |> std/io:print.ln("{{ e.hp:d }}")
