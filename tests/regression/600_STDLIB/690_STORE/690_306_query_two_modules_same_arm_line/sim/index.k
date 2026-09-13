// The store owner: every synthesized unit minted for `items` emits into this
// module's struct, no matter which file armed the query.
import std/io
import std/store

std/store:new(items, capacity: 8) { v: i64 }

pub tor seed { }
seed = std/store:insert(items) { v: 10 } |> std/store:insert(items) { v: 20 }

// The arm below sits on line 14 — ext/index.k's arm sits on line 14 too.
pub tor dump-sim { }
dump-sim = std/store:query(items)
    ! query e |> std/io:print.ln("sim {{ e.v:d }}")
