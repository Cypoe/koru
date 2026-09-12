// A `|>` step after `insert` is the rest of the pipeline, not an insert
// branch: the transform must carry it onto the rewritten call. When the
// site has no `| row`/`| full` arm, the rewrite used to replace the site's
// continuations with an empty list and the second insert never ran.
import std/io
import std/store

std/store:new(items, capacity: 8) { v: i64 }

std/store:insert(items) { v: 10 } |> std/store:insert(items) { v: 20 } |> std/io:print.ln("after")

std/store:query(items)
! query e |> std/io:print.ln("v {{ e.v:d }}")
