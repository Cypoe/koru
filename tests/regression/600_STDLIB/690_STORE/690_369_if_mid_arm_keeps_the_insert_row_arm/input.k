// A `| row` arm written under `|> insert` is the INSERT stage's own
// continuation arm — insert declares no event branches, the transform owns
// it — not a point-free claim over the arm's chain. A `|> if` step earlier
// in the same arm body must not reparent it: the if-headed suffix attempt
// judged `| row` against a truncated stage set where nothing declares
// 'row' and dead-claimed it (KORU021).
import std/store
import std/io

std/store:new(src, capacity: 8) { v: i64 }
std/store:new(dst, capacity: 8) { v: i64 }

std/store:insert(src) { v: 2 }
    | row _ |> std/store:query(src)
        ! query r
            |> if (r.v > 0)
                | then |> std/io:print.ln("hit {{ r.v:d }}")
            |> std/store:insert(dst) { v: r.v }
                | row _ |> std/io:print.ln("copied")
