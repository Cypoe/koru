// PIN (2026-09-18): a combining continuation — `fib(n-1): a |> fib(n-2): b
// -> a + b` — does NOT take the flat segment path. Its leaf returns
// alternate continuation targets, where the native return-address-stack
// predictor beats a dynamic fid dispatch (measured ~20% slower when
// flattened), so the emitter must keep native structured emission.
// post.sh asserts zero __koru_seg_* symbols in the emitted Zig;
// 320_148 pins the chained shape that does qualify.
//
// fib(10) = 55.
import std/io

pub tor fib { n: i64 } -> i64

fib = if(n <= 1)
| then -> n
| else |> fib(n: n - 1): a |> fib(n: n - 2): b -> a + b

fib(n: 10): r |> std/io:print.ln("{{ r:d }}")
