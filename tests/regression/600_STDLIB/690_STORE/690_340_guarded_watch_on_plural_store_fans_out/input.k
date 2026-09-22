// A guarded watch on a PLURAL store: writing the guard field must
// re-announce the watched field on EVERY live row — plural
// `__store_announce_<T>` takes `(row, field)` and a foreign write names
// no row, so the step fans out through a synthesized per-row sweep.
// The singleton shape is 690_013; this pins the plural fan-out.

import std/io
import std/store

std/store:new(board) { alarm: 0[i64] }

std/store:new(sentries, capacity: 4) { post: i64 }

std/store:watch(sentries)
! post p when board.alarm == 1 |> std/io:print.ln("post {{ p:d }} sounds")

std/store:insert(sentries) { post: 7 }
    | row _ |> _
    | full |> _
std/store:insert(sentries) { post: 9 }
    | row _ |> _
    | full |> _

std/store:stored { board.alarm: 1 }
std/store:stored { board.alarm: 0 }
std/store:stored { board.alarm: 1 }
