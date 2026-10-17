// Test: a result-emitting step inside an effect arm's body gets its own
// result_N names — it never reuses the enclosing flow fn's counter.
//
// `produce()` binds result_0 in the flow fn. `lib/pump` carries a
// resume-valued `! tick` arm, so its invocation lowers to a Handlers_N
// struct whose methods are nested inside that flow fn — and the `stored`
// write in the arm body is itself a result-emitting step. The arm body's
// results must be scoped (or depth-indexed) so they cannot shadow the
// outer binding: Zig refuses redeclaration of `result_0` inside a nested
// fn that captures the flow scope.
//
// Surfaced by koru-libs/metal/tests/drift.k (stored inside a `frames`
// arm). The arm-body path goes through emitContinuationBody with a fresh
// `var result_counter: usize = 0` (visitor_emitter.zig ~1969/3627) while
// emitter_helpers.zig already applies depth-indexed `nested_result_{d}`
// hygiene on sibling paths.
//
// v == 0+1+2+3+4+5+6 = 21.

import std/io
import std/store
import lib/pump

std/store:new(s) { v: 0[i64] }

tor produce {}
| ok i64
| err string
proc produce|zig { return .{ .ok = 7 }; }

produce()
| ok n |> lib/pump:pump(n)
    ! tick i |> std/store:stored { s.v: s.v + i } -> i
    | done |> std/io:print.ln("v {{ s.v:d }}")
| err e |> std/io:print.ln("err {{ e:s }}")
