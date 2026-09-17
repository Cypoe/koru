// Pins: Koru `%` on a signed runtime value in a BODY-position expression, on
// BOTH targets — `-> n % 2`, which reaches Zig as the handler's `return`
// expression (see 320_144 for the operator's meaning and spelling).
//
// The hand-off through `via` is what keeps `n` RUNTIME: a literal call site
// const-folds, and the body it folded away is never analyzed by the backend, so
// the pin would pass with the operator never reaching a host.
import std/io

pub tor rem2 { n: i32 } -> i32

rem2 -> n % 2

pub tor via { n: i32 } -> i32

via = rem2(n): r -> r

via(n: 7): a |> std/io:print.ln("rem={{ a:d }}")
via(n: 8): b |> std/io:print.ln("rem={{ b:d }}")
