// TEST: std/panic — the honesty contract. A catch decl answers ONLY the panic
// branches its `!` arms name at sites matching its pattern; every `?!` it
// does not cover keeps the synthesized @panic — pillow subtracts sites from
// the crash surface, it never hides them.
//
// `lethal(code: -2)` fires `?!worse`, which no catch arm answers: the first
// call's `?!bad` lands on the pillow and prints; the second call crashes the
// process exactly as it would without the library.

import std/io
import std/panic

pub tor risky { code: i64 }
| ok i64
| ?!bad i64

pub tor lethal { code: i64 }
| ok i64
| ?!worse i64

risky = if(code < 0)
| then => bad code
| else => ok code

lethal = if(code < 0)
| then => worse code
| else => ok code

std/panic:catch(risky)
! bad v |> std/io:print.ln("caught {{ v:d }}")

risky(code: -1)
| ok v |> std/io:print.ln("ok {{ v:d }}")

lethal(code: -2)
| ok v |> std/io:print.ln("unreachable {{ v:d }}")
