// Glyph discipline, the GRID-SWEEP case — sibling of 400_199 (void effect)
// and 690_357 (`! query` sweep arm). A `=>` inside a `! sweep` arm body can
// never construct: the body clones into the minted per-cell event, which is
// VOID. Without this wall the construct survives checking — the grafted
// body rides under the sweep's synthesized unit — and dies in emitted Zig
// ("type 'void' does not support struct initialization syntax"). The wall
// is the shared pre-graft `refuseUncrossable` (src/ast.zig).
import std/io
import std/store
import std/grid

std/grid:new(cells, size: 4) { count: 0[i64] }
std/store:new(box, capacity: 4) { n: i64 }

tor work {}
| ran
| rejected

work = std/grid:sweep(cells)
! sweep c |> std/io:print.ln("cell {{ c.count:d }}") => ran

std/store:insert(box) { n: 1 }
| row _ |> work()
    | ran |> std/io:print.ln("RAN")
    | rejected |> std/io:print.ln("REJ")
| full |> std/io:print.ln("FULL")
