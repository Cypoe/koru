// Pins: Koru `%` on a SIGNED runtime value in an `if` condition, on BOTH
// targets. Koru's `%` is C's truncated remainder: the comptime fold
// (comptime_eval.zig folds `.modulo` with `@rem` — its own comment calls that
// "the C-parity choice") and the JS target (its `%` on numbers IS that same
// remainder) already agreed; this pins the Zig emission (`@rem`) into the same
// meaning, where bare `%` is unsigned-only and dies at Stage D quoting Zig's
// builtin list. The shape is 320_140's if-dispatch with the numeric operator.
//
// The condition of a `std/control:if` is a per-call TEMPLATE arg, so it is
// baked into the rendered body before the emitter runs — this pins that seam.
import std/io

pub tor parity { n: i32 } -> string

parity = if (n % 2 == 0)
| then -> "even"
| else -> "odd"

// A two-module hand-off, so `n` is a RUNTIME value: a literal call site
// const-folds, and the body it folded away is never analyzed by the backend.
pub tor via { n: i32 } -> string

via = parity(n): r -> r

via(n: 7): a |> std/io:print.ln(a)
via(n: 8): b |> std/io:print.ln(b)
