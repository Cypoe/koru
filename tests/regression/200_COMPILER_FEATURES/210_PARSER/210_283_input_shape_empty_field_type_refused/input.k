// PINS: a tor input shape field whose type is empty (`y: ` between
// commas) refuses PARSE003 at the declaration — a field entry needs both
// halves of `name: type`; the empty half is not a type to splice.
import std/io
tor check { x: i32, y: , z: i32 } -> i32
check -> x + z

check(x: 1, y: 2, z: 3): v |> std/io:print.ln("{{ v:d }}")
