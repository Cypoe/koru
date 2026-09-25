// PINS: a capture seed field whose value is a typed literal `0[i64]` fused
// with the next field refuses with KORU164 naming the missing comma. The
// `]`-closed `0[i64]` is a value annotation, not a type prefix — the
// fusedFieldLine qualifier exemption is for `[`-led and `const`-led tokens.
// Shape: 210_256's capture seed, one comma dropped.
import std/io

pub tor tick { n: i64 }

tick = capture { acc: 0[i64] extra: 0[i64] }
! as st |> captured { acc: st.acc + 1 }
| captured r |> std/io:print.ln("{{ r.acc:d }}")

tick(n: 1)
