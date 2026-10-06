// 011 — the LINQ post's headline task, on cs: filter -> map -> sum over
// 1..n. `when` on `! each` is the Where, `* 3` the Select, `acc` the Sum.
// The claim under test: generated cs for this shape vs LINQ and a
// handwritten foreach on the same runtime.
import std/io

pub tor acc { v: i64 }

pub tor run { n: i64 }

run = for(1..(@as(usize, @intCast(n)) + 1))
    ! each i when i % 2 == 0 |> acc(v: @as(i64, @intCast(i)) * 3)

run(n: 10) |> std/io:print.ln("total={{ total:d }}")
