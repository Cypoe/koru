// 690_370 — an `! each` loop binding reaches a nested store query's `when`
// guard.
//
// Pins the capture threading for wildcard-payload arm binds: `each`'s
// payload is `*`, which lookupBranch cannot type, so collectBindsOnPath
// derives the element type from the `for` expr — `a..b` iterates usize,
// an `&[_]T{…}` literal iterates T, and a bare `for(name)` resolves off
// the named bind's own `[]T`/`[N]T` in a second pass. An iterable whose
// element cannot be named stays "?" and refuses with teaching if a body
// captures it (the `| none` twin refuses the same way in store.qnone).
//
// The captured `i` rides every hop — sweeprun Input, sweepbody Input —
// so `p.d == i` evaluates inside the inner sweep's handler frame.
import std/io
import std/store

std/store:new(spec, capacity: 8) { d: i64 }
std/store:insert(spec) { d: 1 }

for(0..2)
! each i |> std/store:query(spec)
    ! query s
        |> std/store:query(spec)
            ! query p when p.d == i
                |> std/io:print.ln("hit")
