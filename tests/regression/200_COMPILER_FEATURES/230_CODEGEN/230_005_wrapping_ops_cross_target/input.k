// Cross-target WRAPPING arithmetic: `*%` `+%` `-%` are Zig operator spellings
// with no JavaScript counterpart. On the JS lane codegen_utils' lowerJsInto
// rewrites them — `*%` to `Math.imul(a, b)`, `+%`/`-%` to `| 0` coercions —
// and a miss there leaks the operator verbatim into output_emitted.js as a
// syntax error. The operands live in a store cell: cell reads are opaque to
// const-folding, so the operators reach the host emit as RUNTIME wrapping
// arithmetic on both lanes (literal operands would const-fold on the Zig lane
// and refuse before ever exercising the wrap). Every pair is chosen so the
// wrapping answer differs from the plain one.
import std/io
import std/store

std/store:new(w) { wa: 2000000000[i32], wb: 2147483647[i32], wc: -2147483647[i32] }

pub tor wmul { a: i32, b: i32 } -> i32
wmul -> a *% b

pub tor wadd { a: i32, b: i32 } -> i32
wadd -> a +% b

pub tor wsub { a: i32, b: i32 } -> i32
wsub -> a -% b

wmul(a: w.wa, b: 3): x |> std/io:print.ln("wmul={{ x:d }}")
wadd(a: w.wb, b: 1): y |> std/io:print.ln("wadd={{ y:d }}")
wsub(a: w.wc, b: 2): z |> std/io:print.ln("wsub={{ z:d }}")
