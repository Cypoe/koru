// RED BY DESIGN (pinned 2026-07-25). `/` on a SIGNED runtime operand emits bare
// Zig `/`, which Zig rejects:
//
//   error: division with 'i64' and 'comptime_int': signed integers must use
//          @divTrunc, @divFloor, or @divExact
//
// A raw host error, not a koru diagnostic — the wall is not built here yet.
// NEEDS_RULING holds the decision: lower (needs the operand's TYPE — `@divTrunc`
// is truncating division and `/` is exact, so int-vs-float cannot be decided by
// spelling) or refuse in Koru, naming the signedness.
//
// SHOWN 2026-07-25, characterised: signed `/` fails, unsigned `/` works (usize
// prints 5), signed `*` works. So it is specific to signed division, not
// arithmetic generally. The remainder half of that characterisation — signed `%`
// fails — was FIXED 2026-09-17 (`@rem`, decidable without a type; pinned by
// 010_063 and 320_144/145/146), which is why this pin now carries `/` alone.
//
// Why it survived: koru's own COMPTIME evaluator already gets `/` right —
// src/comptime_eval.zig uses @divTrunc and its comment calls that "the C-parity
// choice". The runtime emitter has no matching lowering, and the corpus has zero
// tests dividing a signed runtime value (everything divides literals, which
// const-fold, or divides usize). Comptime and runtime disagree about the same
// operator.
//
// Found from the outside: building a multi-file ledger app in koru-examples,
// where `cents / 100` compiled while the entry passed a literal and broke the
// moment a second module passed the value through at runtime.
import std/io

pub tor f { n: i64 } -> i64
f -> n / 2

pub tor go { n: i64 } -> i64
go = f(n): h -> h

go(n: 10): x |> std/io:print.ln("half={{ x:d }}")
