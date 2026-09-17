// Pins: Koru `%` on a signed runtime payload field in a call-site `when`
// guard, on BOTH targets — 320_142's string-guard shape with the numeric
// operator Zig spells differently (`@rem`, see 320_144). A guard is a
// condition like any other, so the same operator spelling has to reach this
// emission. Each guard TAKES its arm, so the rewritten comparison is on the
// executed path, not merely compiled.
import std/io

pub tor fetch { id: i64 }
| found { n: i32, tag: i32 }
| missing

fetch = if (id == 1)
| then => found { n: 7, tag: 1 }
| else => found { n: 8, tag: 2 }

fetch(id: 1)
| found { n, _ } when n % 2 != 0 |> std/io:print.ln("odd {{ n:d }}")
| found { n, _ } |> std/io:print.ln("even {{ n:d }}")
| missing |> std/io:print.ln("nope")

fetch(id: 2)
| found { n, _ } when n % 2 == 0 |> std/io:print.ln("even {{ n:d }}")
| found { n, _ } |> std/io:print.ln("odd {{ n:d }}")
| missing |> std/io:print.ln("nope")
