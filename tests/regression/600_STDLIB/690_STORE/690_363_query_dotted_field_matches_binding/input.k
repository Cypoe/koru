// 690_363 — `.name` under a query is a field of the OTHER expression, not
// the row binding.
//
// Under `! query v`, the nested `| item it` arm reads `it.v` — a field of
// the taken row — while the query's own binding is `v`. A bare-binding
// rewrite that fires on `.v` mints `__koru_store_A.__koru_handle_of` into the
// middle of `it.v`, corrupting a field access on an unrelated binding. Same
// family as 690_361 (`:name` spec position) and 690_362 (`name:` arg/field
// position) — the binding only sits in value position, and adjacency decides
// which is which. The same body also uses `v` correctly in `A[v]`, so both
// halves of the rule are pinned in one program.
import std/io
import std/store

std/store:new(A, capacity: 4) { v: i64 }

std/store:insert(A) { v: 7 }
    | row _ |> _
    | full |> _

std/store:query(A)
! query v |> std/store:take(A[v])
    | item it |> std/io:print.ln("{{ it.v:d }}")
    | empty |> _
