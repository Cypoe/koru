// PINS the C lane counted-loop shape: `for(0..N)` renders a C `for` whose
// trip count is in the header — never a `while` — and the `! each` arm is
// transplant vocabulary resolved through the `__koru_inline_scoped_N` splice
// (the range item bound into the handler body), not a resumable pair.
// `| done` drains through `__koru_continue_N`.
import std/io

for(0..3)
! each i |> std/io:print.ln("{{ i:d }}")
| done |> std/io:print.ln("done")
