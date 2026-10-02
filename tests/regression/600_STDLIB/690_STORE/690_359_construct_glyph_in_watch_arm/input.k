// Glyph discipline, the WATCH-ARM case — sibling of 690_357 (`=>` in a
// `! query` sweep arm). A `=>` inside a `! <field>` watch arm can never
// construct: the arm body grafts into a synthesized VOID interceptor unit,
// so the enclosing tor's branch cannot be produced from in there. Without
// the wall the construct survives checking (the graft is marked
// is_transformed_subtree, which checkers skip) and dies in emitted Zig.
// The wall lives in the store:watch transform, pre-graft — on BOTH watch
// collection paths (singleton and plural).
import std/io
import std/store
std/store:new(box, capacity: 4) { n: i64, m: i64 }
std/store:watch(box)
! n v |> std/io:print.ln("changed {{ v:d }}") => ran

tor work {}
| ran
| rejected

work = std/store:insert(box) { n: 1, m: 2 }
| row _ |> std/io:print.ln("ok")
| full |> std/io:print.ln("full")

work()
| ran |> std/io:print.ln("RAN")
| rejected |> std/io:print.ln("REJ")
