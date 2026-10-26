// One `{ ... }` produce stage per `! each` arm: `{ f } { g }` is refused
// until the stage-list grammar lands — each `{ }` replaces the downstream
// scope, so a second stage is a different grammar than two adjacent braces
// suggest.
import std/io

for(1..4)
    ! each i { double: i * 2 } { triple: double * 3 } |> std/io:print.ln("{{ triple:d }}")
