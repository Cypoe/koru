// std/rings — ops are name-addressed: the ring word must name a ring
// this program declared. An undeclared name refuses and points at the
// declaration.
import std/rings

std/rings:enqueue(nope, v: 1)
| ok |> _
| full |> _
