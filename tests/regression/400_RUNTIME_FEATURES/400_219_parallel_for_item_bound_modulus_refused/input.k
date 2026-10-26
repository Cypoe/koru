// [parallel]for: a @rem-fold whose MODULUS is item-bound isn't a fold —
// the join would replay @rem(_, i) with `i` unbound. Refuse, don't emit.
import std/io

capture { acc: 0[i64] }
! as a |> [parallel]for(2..101)
    ! each i |> captured { acc: @rem(a.acc + 7, @as(i64, @intCast(i))) }
| captured r |> std/io:print.ln("{{ r.acc:d }}")
