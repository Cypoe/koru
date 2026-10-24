// `! else` arms carry the same stage grammar as `! each` — `{ }` projects
// in the else's own scope and a trailing `when` guards the produced names.
// The exclusive dispatch composes with projection: `d6` fires because i=3
// is not a multiple of 4 (the each guard failed) AND d=6>4 (the else's own
// post-produce guard passed). `{ i }` puns the bound element itself — a
// carry-through, not a field read.
import std/io

for(1..8)
    ! each i when i % 4 == 0 |> std/io:print.ln("q{{ i:d }}")
    ! else i { d: i * 2 } when d > 4 |> std/io:print.ln("d{{ d:d }}")

for(1..5)
    ! each i { i } |> std/io:print.ln("c{{ i:d }}")
