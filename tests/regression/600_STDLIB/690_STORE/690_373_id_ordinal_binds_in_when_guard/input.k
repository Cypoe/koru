// 690_373 — `[id]` and `[ordinal]` request binds are visible in the arm's
// own `when` guard, not only in its body.
//
// The request binds mint their per-row values at the sweep's handler call
// site — `{ .sh = __koru_handle_of(__koru_si) }` — but the `when` guard runs
// in the sweep loop BEFORE that call, where only the dense cursor exists.
// store.qguard.kz substitutes the capture's own expression into the guard
// text: the branded handle for `[id]`, the i64-cast cursor for `[ordinal]`.
// Covers `! query` and `! first`; a nested indexed read of the guard's own
// store (`rows[sh].v`) resolves through the same substitution.
import std/io
import std/store

std/store:new(world) { n: 0[i64] }
std/store:new(rows, capacity: 8) { v: i64 }

std/store:insert(rows) { v: 10 }
    | row a |> std/store:insert(rows) { v: 20 }
        | row b |> std/store:insert(rows) { v: 30 }
            | row c |> std/store:query(rows)
                ! query { [row]s, [ordinal]ord } when ord == 2
                    |> std/store:stored { world.n: world.n + s.v }
                |> std/store:query(rows)
                    ! first { [row]f, [id]fh } when rows[fh].v == 20
                        |> std/store:stored { world.n: world.n + 1000 }
                        |> std/io:print("n {{world.n:d}}\n")
