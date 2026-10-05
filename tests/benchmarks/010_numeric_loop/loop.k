// 010 — a real generated loop: `for` over a range, per-element typed math
// (`work`), a per-element state write (`acc` via |cs host text). The claim
// under test: a Koru event-loop on cs costs what a handwritten C# loop
// costs — dispatch hops plus plain arithmetic, nothing else in between.
import std/io

pub tor work { i: i64 } -> i64
work -> i * i + i

pub tor acc { v: i64 }

pub tor run { n: i64 }

run = for(0..@as(usize, @intCast(n)))
    ! each i |> work(i: @as(i64, @intCast(i))): r |> acc(v: r)

run(n: 30) |> std/io:print.ln("total={{ total:d }}")
