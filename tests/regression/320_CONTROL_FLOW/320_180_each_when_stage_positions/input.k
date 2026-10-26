// `when` is the only guard word, and it takes either stage position on an
// each arm: before the `{ }` it guards the binding scope, after it guards
// the produced scope. `! each i when c { f }` filters the element, then
// projects — the `when` cannot see produced names. `! each i { f } when c`
// projects, then filters the projection. The chain `when c { f } when c2`
// is the same two operators folded — filter, project, filter again.
import std/io

for(1..8)
    ! each i when i % 2 == 0 { double: i * 2 } |> std/io:print.ln("a{{ double:d }}")

for(1..8)
    ! each i { double: i * 2 } when double > 6 |> std/io:print.ln("b{{ double:d }}")

for(1..8)
    ! each i when i % 2 == 0 { double: i * 2 } when double > 6 |> std/io:print.ln("c{{ double:d }}")
