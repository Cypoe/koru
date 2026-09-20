// NAME COLLISION — a store whose identifier collides with a koru_std
// local must still elide handle machinery. The handle gate walks the
// whole program scanning text slots for `store[` index expressions and
// bare row-binding reads; koru_std's own bodies are full of both on
// locals that can never name a program store — `.items[` (the
// ArrayList idiom all over store.new.kz), `names[i] = field.name`
// (store.kz), `data[wi]` (field.kz), `fields[i]` (interpreter.run).
// Before the gate scoped its scan to modules that can actually name
// the store — and excluded `.name[` member access from the match —
// every one of these stores kept its hslot freelist, generation table,
// and per-insert handle stores purely because of the identifier.
// `items`/`names`/`data`/`fields` below are all observation-free and
// must emit lean: no hslot, no resolve, and the counted fill bulks.
import std/io
import std/store
import std/control

std/store:new(items, capacity: 8) { on: i64 }
std/store:new(names, capacity: 8) { on: i64 }
std/store:new(data, capacity: 8) { on: i64 }
std/store:new(fields, capacity: 8) { on: i64 }

for(0..4)
! each i |> std/store:insert(items) { on: @intCast(i) }

for(0..4)
! each i |> std/store:insert(names) { on: @intCast(i * 2) }

for(0..4)
! each i |> std/store:insert(data) { on: @intCast(i * 3) }

for(0..4)
! each i |> std/store:insert(fields) { on: @intCast(i * 4) }

std/store:query(items)
! query e |> std/io:print.ln("items {{ e.on:d }}")

std/store:query(names)
! query e |> std/io:print.ln("names {{ e.on:d }}")

std/store:query(data)
! query e |> std/io:print.ln("data {{ e.on:d }}")

std/store:query(fields)
! query e |> std/io:print.ln("fields {{ e.on:d }}")
