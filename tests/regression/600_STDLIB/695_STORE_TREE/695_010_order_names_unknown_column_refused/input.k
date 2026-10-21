// 695_010 — `order:` names a column that does not exist on the store.
// The sweep would sift by a field it cannot read, so the create refuses at
// declaration time with the column named in the diagnostic.
import std/io
import std/store

[tree]std/store:new(tree, capacity: 64) { val: i64, ord: i64 }

std/store:insert(tree) { val: 10, ord: 1 }

std/store:preorder(tree, order: "rank")
! preorder e |> std/io:print.ln("{{ e.val:d }}")
