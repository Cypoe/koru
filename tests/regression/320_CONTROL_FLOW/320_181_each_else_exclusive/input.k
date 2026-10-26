// `! each` arms are parallel handlers — every matching arm fires. `! else`
// opts the contiguous each/else run into exclusive dispatch: it fires only
// when no earlier arm in the run did, `! else when ...` is else-if, and a
// bare `! else` is the residual. The run is the grammar's if/else-if/else
// chain spelled on the `!` axis; the parallel default is untouched — two
// unguarded `! each` arms still both fire.
import std/io

for(1..16)
    ! each i when i % 15 == 0 |> std/io:print.ln("fizzbuzz")
    ! else i when i % 3 == 0 |> std/io:print.ln("fizz")
    ! else i when i % 5 == 0 |> std/io:print.ln("buzz")
    ! else i |> std/io:print.ln("{{ i:d }}")

for(1..4)
    ! each i |> std/io:print.ln("p{{ i:d }}")
    ! each i |> std/io:print.ln("q{{ i:d }}")
