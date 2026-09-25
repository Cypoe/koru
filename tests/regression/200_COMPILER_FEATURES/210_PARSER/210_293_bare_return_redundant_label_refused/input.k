// PINS: a redundant explicit label in a bare-return produce — `{ a: a }` —
// refuses the pun law (PARSE005), same as the constructor-field path.
// `a: a` puns to `a`; writing the label is the redundant form the law drops
// at emit time, leaving `missing struct field` errors.
import std/io

pub tor f { a: i64 } -> { a: i64, z: i64 }
f -> { a: a, z: 1 }
f(a: 4): r |> std/io:print.ln("{{ r.a:d }}")
