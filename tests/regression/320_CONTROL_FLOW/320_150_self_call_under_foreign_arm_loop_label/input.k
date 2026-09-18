// Pins self-call emission through a call-result arm: a self-call reachable
// ONLY through another event's arm — the restart-inside-the-crash-handler
// shape — must lower to reassign+`continue :__koru_self_loop` like any
// other tail self-call. The subflow bail path builds a fresh
// EmissionContext for emitContinuationBody; it must carry the enclosing
// handler's self_loop flags or the arm emits a plain nested `handler()`
// call and the loop label goes unused.
//
// Why this shape matters: it IS the supervision shape. "Claim the child's
// `?!` branch and re-enter the unit" — an Erlang restart — is definitionally
// a self-call nested inside a foreign event's panic arm. The flat-segment
// path (320_148) only covers self-calls chained through `if` continuations;
// this arm-nested form is the sibling.
//
// worker(-7) => boom; sup claims boom, re-enters with fresh args (f * -1 =
// the restart's init), succeeds on the second pass => prints 7.
import std/io

pub tor worker { n: i64 }
| ok i64
| ?!boom i64

worker = if(n < 0)
| then => boom n
| else => ok n

pub tor sup { n: i64 } -> i64

sup = worker(n)
| ok v -> v
| boom f |> sup(n: f * -1): v -> v

sup(n: -7): r |> std/io:print.ln("{{ r:d }}")
