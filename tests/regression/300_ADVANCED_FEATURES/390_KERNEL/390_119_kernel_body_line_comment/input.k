// TEST: a `//` comment inside a multi-line kernel op body is block content,
// not a truncator — the step's comment strip runs per line, so the block's
// closing `}` survives (was PARSE001).

import std/io
import std/store
import std/kernel

std/store:new(world, capacity: 8) { x: f64, kind: f64 }
std/store:insert(world) { x: 0.0, kind: 0.0 }
std/store:insert(world) { x: 1.0, kind: 1.0 }

std/kernel:init(world) {}
| kernel k |> std/kernel:self {
        // bump every row by ten
        k.x += 10.0;
    }

std/store:query(world)
! query r |> std/io:print.ln("x {{ r.x:f }}")
