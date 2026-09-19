// PIN: `@as(i64, @intCast(x))` — the canonical Koru cast — and index-position
// `@intCast(x)` lower through `__koru_intcast`, never bare `@intCast`. Zig's
// @intCast emits an `llvm.assume` (operand-fits hint) at the cast site; inside
// a loop body the vectorizer reads the assume as an opaque call and declines
// the loop — measured 5.9ms scalar vs 1.5ms vectorized for the same
// runtime-bound fold (koru-benchmarks suites/iteration-models). The helper
// bitcasts same-width sign flips in release; Debug/ReleaseSafe keep the real
// fit-check. post.sh pins the emitted spelling, expected.txt the value.
import std/io

capture { sum: 0[i64], g: [4]i64{ 3, 1, 4, 1 } }
! as acc |> for(0..4)
    ! each i |> captured { sum: acc.sum + @as(i64, @intCast(acc.g[@intCast(i)])) * 3 }
| captured fin |> std/io:print.ln("{{ fin.sum:d }}")
