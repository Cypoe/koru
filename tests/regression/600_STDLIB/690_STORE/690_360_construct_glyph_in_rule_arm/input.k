// Glyph discipline, the RULE-ARM case — sibling of 690_357 (`=>` in a
// `! query` sweep arm). A `=>` inside a `! row`/`! preorder` arm of
// std/store:rule can never construct: the arm body grafts into the same
// synthesized VOID per-row unit the query sweep uses, so the enclosing
// tor's branch cannot be produced from in there. Without the wall the
// construct survives checking (the graft is marked is_transformed_subtree,
// which checkers skip) and dies in emitted Zig. The wall lives in the
// store:new transform's qsites collection, pre-graft.
import std/io
import std/store
std/store:new(box, capacity: 4) { n: i64 }

tor work {}
| ran
| rejected

std/store:rule(box)
! row e |> std/io:print.ln("row {{ e.n:d }}") => ran

std/store:insert(box) { n: 1 }
| row _ |> std/io:print.ln("ok")
| full |> std/io:print.ln("full")
