// `! each i { double: i * 2 }` — the produce stage on an each arm: one
// const per listed name, the RHS evaluated in the pre-stage scope, and
// only the listed names flow downstream — the `{ }` is the SELECT list.
// `{ i }` puns the bound element itself: a carry-through, `i` keeps its
// value with no new const. `{ i: i + 1 }` is a legal rebind — the stage
// REPLACES scope, so the RHS reads the old `i` while the LHS mints the
// stage's `i`; `{ i: i }` instead refuses under must-pun (210_330).
import std/io

for(1..4)
    ! each i { double: i * 2 } |> std/io:print.ln("d{{ double:d }}")

for(1..4)
    ! each i { i, double: i * 2 } |> std/io:print.ln("{{ i:d }}x2={{ double:d }}")

for(1..4)
    ! each i { i: i + 1 } |> std/io:print.ln("n{{ i:d }}")
