// Pins: a captured write under [parallel] that is NOT a provably additive
// fold must refuse — partitioning without a combine law is a wrong answer,
// not a missing feature.
import std/io

capture { acc: 0[i64] }
! as a |> [parallel]for(1..9)
    ! each i |> captured { acc: @max(a.acc, @as(i64, @intCast(i))) }
| captured r |> std/io:print.ln("{{ r.acc:d }}")
