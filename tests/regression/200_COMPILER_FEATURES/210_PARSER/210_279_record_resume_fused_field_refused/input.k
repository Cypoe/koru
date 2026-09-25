// PINS: a record resume whose second field's type runs into a third
// `name: type` on the same line (`b: i64 c: i64`, comma dropped) refuses
// PARSE003 at the declaration — every `{`-led resume type is validated by
// the one field parser, not only comma-free ones. The resume-side sibling
// of 210_276's record-return pin.
import std/io
pub tor request { seed: i64 }
! ask -> { a: i64, b: i64 c: i64 }
| done i64
request = ask(): c => done c.a
request(seed: 8)
! ask -> { a: 10, b: 20, c: 30 }
| done r |> std/io:print.ln("{{ r:d }}")
