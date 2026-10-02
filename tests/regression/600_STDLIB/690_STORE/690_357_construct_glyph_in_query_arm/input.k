// Glyph discipline, the SWEPT-ARM case — sibling of 400_199 (`=>` on a void
// effect under a real handler). A `=>` inside a `! query` arm body can never
// construct: the body grafts into a synthesized VOID per-row unit, so the
// enclosing tor's branch cannot be produced from in there. Without this wall
// the construct survives checking — the grafted body is marked
// is_transformed_subtree, which checkers skip — and dies in emitted Zig
// ("type 'void' does not support struct initialization syntax" inside the
// synthesized sweepbody). The wall lives in the query transform, pre-graft,
// where the user body is still visible.
// Pure-.k realization of kopium wired/holes/10's remaining gap.
import std/io
import std/store

std/store:new(box, capacity: 4) { n: i64 }

tor work {}
| ran
| rejected

work = std/store:query(box)
! query e |> std/io:print.ln("row {{ e.n:d }}") => ran

std/store:insert(box) { n: 1 }
| row _ |> work()
    | ran |> std/io:print.ln("RAN")
    | rejected |> std/io:print.ln("REJ")
| full |> std/io:print.ln("FULL")
