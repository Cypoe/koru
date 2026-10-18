// 690_370 — an `! each` loop binding reaches a nested store query's `when`
// guard.
//
// The outer query's `when` sees `i` (it lowers inline in the loop body);
// the INNER query lowers to a separate sweeprun handler fn whose Input
// packs only row fields — the enclosing binding is not threaded as a
// capture. The expected behavior once the gap closes: `i` binds in the
// nested guard, `p.d == i` matches the seeded row when i == 1, and the
// program prints one `hit`.
//
// Surfaced by clay/tests/spec.k's measure pass, which wanted
// `for (0..8) ! each i |> query … when s.d == (7 - i)` — routed to
// explicit depth-bounded sweeps pending this.
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
