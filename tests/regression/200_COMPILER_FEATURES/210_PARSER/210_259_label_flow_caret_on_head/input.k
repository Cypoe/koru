// PINS: Flow.location on the label-declared flow path (`#lbl capture { … }`)
// names the `#lbl` head line. The capture seed refusal rides flow.location.
import std/io

pub tor tick { n: i64 }

#lbl capture { p: 0[i64], p: 0[i64] }
! as st |> captured { p: st.m }
| captured r |> std/io:print.ln("{{ r.p:d }}")

tick(n: 1)
