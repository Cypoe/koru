// `{ i: i }` in a produce stage is the redundant rename — the pun spelling
// `{ i }` already says it, so must-pun refuses it. `:` inside produce
// braces is for renames and computations (`{ i: i + 1 }`, `{ x: it.k }`),
// never the same name on both sides.
import std/io

for(1..4)
    ! each i { i: i } |> std/io:print.ln("{{ i:d }}")
