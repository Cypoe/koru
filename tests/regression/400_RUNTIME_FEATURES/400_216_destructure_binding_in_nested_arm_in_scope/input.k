// PINS: KORU108 — an arm-level destructure `! query { [row]s, [ordinal]o }`
// binds `s` and `o` on the arm's own path, so references inside its nested
// `|> if | then |>` body are in scope even though the same names are bound
// on DISJOINT paths elsewhere in the flow (the `| row s` / `| row o` binds
// inside the `| full` arms put both names in the flow's bound-name set).
// Guards the single bind-site enumeration the bound set and the path scope
// share: a bind kind the scope walk misses but the set records flags its
// own users.
import std/io
import std/store

std/store:new(pts, capacity: 4) { x: i64 }

pub tor show { v: i64 }

show = std/io:print.ln("v {{ v:d }}")

std/store:insert(pts) { x: 5 }
| row r1 |> std/store:insert(pts) { x: 7 }
    | row r2 |> std/store:query(pts)
        ! query { [row]s, [ordinal]o }
            |> if (o == 0)
                | then |> show(v: s.x)
            |> if (o == 1)
                | then |> show(v: o)
    | full |> std/store:insert(pts) { x: 9 }
        | row s |> _
| full |> std/store:insert(pts) { x: 9 }
    | row o |> _
