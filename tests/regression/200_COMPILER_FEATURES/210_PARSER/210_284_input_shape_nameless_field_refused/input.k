// PINS: a tor input shape entry with a colon but no name (`: i32`)
// refuses PARSE003 at the declaration — a field needs both halves of
// `name: type`; a nameless field binds nothing the author can call.
import std/io
tor check { x: i32, : i32, z: i32 } -> i32
check -> x + z

check(x: 1, z: 3): v |> std/io:print.ln("{{ v:d }}")
