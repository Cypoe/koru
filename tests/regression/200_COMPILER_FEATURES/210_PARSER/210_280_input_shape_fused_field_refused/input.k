// PINS: a tor input shape whose second field's type runs into a third
// `name: type` on the same line (`y: i32 z: i32`, comma dropped) refuses
// PARSE003 at the declaration — a fused field is not a type, and the
// field list refuses it rather than mis-reading the tail as a module
// qualifier on the field above. The input-shape sibling of 210_276's
// record-return pin.
import std/io
tor check { x: i32, y: i32 z: i32 }
| high i32
| low i32

check => high x

check(x: 10, y: 5)
| high h when h > 10 |> _
| high _ |> _
| low _ |> _
