// 690_362 — a field/arg NAME glued to `:` is not the row binding.
//
// A store row block spells fields `name: value`, and when the query binding
// shares a name with a target column (`{ v: v.v }` under `! query v`) the
// bare-binding rewrite must leave the field name alone — only the value
// position rewrites to the column read. The mask cannot help here: name
// position is an adjacency rule, not a literal/spec region. Same family as
// 690_361 (`:name` spec) and 690_363 (`.name` field) — identifier-adjacent
// punctuation marks name position, not a use of the binding.
import std/io
import std/store

std/store:new(A, capacity: 4) { v: i64 }
std/store:new(B, capacity: 4) { v: i64 }

std/store:insert(A) { v: 7 }
    | row _ |> _
    | full |> _

std/store:query(A)
! query v |> std/store:insert(B) { v: v.v }
    | row _ |> _
    | full |> _

std/store:query(B)
! query b |> std/io:print.ln("{{ b.v:d }}")
