// PINS: `capture { ... }` seed is a Source-argument field list — a repeated `p`
// is refused by struct_literal's one-name rule, surfacing as KORU164 through
// the transform's own parse path, caret on the capture head line.
import std/io

pub tor tick { n: i64 }

tick = capture { p: 0[i64], p: 0[i64] }
! as st |> captured { p: st.m, m: st.p }
| captured r |> std/io:print.ln("{{ r.p:d }} {{ r.m:d }}")

tick(n: 1)
