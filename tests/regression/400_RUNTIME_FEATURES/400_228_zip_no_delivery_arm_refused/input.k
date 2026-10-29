import std/io
import std/control

// A `zip` whose pairs are delivered to nobody is refused: `! each` is the
// only delivery arm, and without it the call walks to nothing.

std/control:zip(a: 1..3, b: 10..13)
| done n |> std/io:print.ln("{{ n:d }}")
