// A store declared in a non-entry module: the backing `var` must emit into
// THIS module's struct, and every op generated for it (insert/query/kernel)
// must reference it there — `sim_mod.__koru_store_items`, not a var that
// landed in the importer's top-level scope (found via koru-libs
// games/ponkatris: the engine module could not own its world store).

import std/io
import std/store

std/store:new(items, capacity: 8) { v: i64 }

pub tor seed { }

seed = std/store:insert(items) { v: 10 } |> std/store:insert(items) { v: 20 }

pub tor dump { }

dump = std/store:query(items)
    ! query e |> std/io:print.ln("v {{ e.v:d }}")
