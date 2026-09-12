// A module's top-level flows are its initialization: they run before the
// importing module's own flows, so a store seeded at module top level is
// already populated when the entry's flows query it.

import std/store
import std/io

std/store:new(items, capacity: 8) { v: i64 }

std/store:insert(items) { v: 10 }
std/store:insert(items) { v: 20 }

pub tor show { }

show = std/store:query(items)
    ! query e |> std/io:print.ln("v {{ e.v:d }}")
