// PINS: `captured { ... }` is a Source-argument field list — a repeated `p`
// is refused by struct_literal's one-name rule, surfacing as KORU164 through
// the transform's own parse path. At HEAD it compiled and RAN, silently
// overwriting the first binding (printed `1 0`).
import std/io

pub tor tick { n: i64 }

tick = capture { p: 0[i64], m: 0[i64] }
! as st |> captured { p: st.m, m: st.p, p: st.m + 1 }
| captured r |> std/io:print.ln("{{ r.p:d }} {{ r.m:d }}")

tick(n: 1)
