// Glyph discipline, the INTERCEPTOR-ARM case — sibling of 690_357 (`=>` in a
// `! query` sweep arm). A `=>` inside a `! inserted`/`! removed`/`! updated`/
// `! cleared`/`! discharge` arm can never construct: the arm body grafts into
// a synthesized VOID interceptor unit, so the enclosing tor's branch cannot
// be produced from in there. Without the wall the construct survives checking
// (the graft is marked is_transformed_subtree, which checkers skip) and dies
// in emitted Zig. The wall lives in the store:new transform, pre-graft.
// `! step`/`! wait` arms are deliberately exempt: a participant's `=>`
// constructs its own declared verdicts (690_309).
import std/io
import std/store
std/store:new(box, capacity: 4) { n: i64 }
! inserted { n } |> std/io:print.ln("born {{ n:d }}") => ran

tor work {}
| ran
| rejected

work = std/store:insert(box) { n: 1 }
| row _ |> std/io:print.ln("ok")
| full |> std/io:print.ln("full")

work()
| ran |> std/io:print.ln("RAN")
| rejected |> std/io:print.ln("REJ")
