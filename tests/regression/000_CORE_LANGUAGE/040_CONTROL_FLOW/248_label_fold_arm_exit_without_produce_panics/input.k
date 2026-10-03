// A `| err _ |> _` arm nested inside a `#L` fold's looping arm exits the fold
// without producing — in a void flow that arm-end is a legitimate fold exit
// (247's contract), but inside `run -> i64` the fold still owes a value. The
// emitter terminates that path with a loud @panic naming the shape instead of
// falling off the end of a non-void fn and dying at the Zig level.
//
// The hole is never taken here (boom always produces `ok` for x >= 0), so the
// pin is that this shape COMPILES AND RUNS: before the guard, the emitted
// `__koru_handler_impl` was invalid Zig — the sibling defect that made the
// drag-race faithful.k uncompilable.

import std/io
import std/control

tor tick { deadline: i128, passes: i64 }
| live { deadline: i128, passes: i64 }
| expired i64

tor run { deadline: i128 } -> i64

tor boom { x: i64 }
| ok i64
| err i64

tick = if(passes < 2)
| then => live { deadline, passes }
| else => expired passes

boom = if(x < 0)
| then => err x
| else => ok x

run = #L tick(deadline, passes: 0)
| live l |> boom(x: 5)
    | ok v |> @L(l.deadline, passes: l.passes + v)
    | err _ |> _
| expired e -> e

run(deadline: 0): r |> std/io:print.ln("{{ r:d }}")
