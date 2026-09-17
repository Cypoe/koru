// Pins: the NAIVE Koru `%` operator on a signed i64 must compile, run, and be
// C-fast — no raw `@mod`/`@rem` in the source. `%` is C's truncated remainder
// (comptime_eval.zig folds `.modulo` with `@rem`, its own comment calling that
// "the C-parity choice"; the JS target's `%` on numbers is the same operator),
// so a `.k` author writing `%` and a `.k` author writing `@mod` must not be
// writing two different languages.
//
// The shape is a `captured { }` cell RHS: field values are raw expression text
// reaching Zig, which is where the spelling has to be applied.
//
// Semantics check: for i in [2,5): acc=0 -> (0+7)%2=1 -> (1+7)%3=2 -> (2+7)%4=1.
import std/io

capture { acc: 0[i64] }
! as a |> for(2..5)
    ! each i |> captured { acc: (a.acc + 7) % @as(i64, @intCast(i)) }
| captured r |> std/io:print.ln("{{ r.acc:d }}")
