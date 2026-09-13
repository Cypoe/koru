// Nested `for` under a `! query` arm must lower on BOTH lanes. The query
// transform transplants the arm body into a synthesized sweepbody flow
// whose head is the `for` invocation — rendered by renderNestedTemplates
// onto `inv.inline_body` BEFORE the transform ran, so `flow.inline_body`
// is null while `flow.inv().inline_body` carries the body. The zig subflow
// dispatch only read `flow.inline_body` and emitted the raw
// `for_event.handler(.{ .expr = 0..2 })` — a dropped loop plus a verbatim
// range literal, which is invalid Zig. JS read `inv.inline_body` through
// emitInvocationWithContinuations and worked. (Asteroids paint-rocks.)
import std/store
import std/io

std/store:new(items, capacity: 16) { n: i32 }

for(0..2)
! each k |> std/store:insert(items) { n: @as(i32, @intCast(k)) }
    |> std/store:query(items)
        ! query e |> for(0..2)
            ! each i |> std/io:print.ln("q {{ e.n:d }} i {{ i:d }}")
