// ga-cell: branch_arm__obligation
// ga-cell: branch_arm__record
// Pins the enclosing-arm claim on plain declared tors — the fold is a
// language rule, not a std/rings trick. `try-inner` nested under `| ok`
// produces a void `full` with no arm at its level; the level-1 `| full`
// is the nearest enclosing same-named arm and must claim it. OWED:
// today coverage is sibling-level only (KORU022).
import std/io

pub tor try-inner { n: i64 }
| ok i64
| full

try-inner = if(n > 0)
| then => ok n
| else => full

try-inner(n: 5)
| ok v |> try-inner(n: v - 6)
    | ok w |> std/io:print.ln("inner ok {{ w:d }}")
     ! query e |> std/io:print.ln("n {{ n:d }} v {{ e.v:d }}")
     std/store:new(arena, capacity: 32) { u: *app/lib/unit:Unit<live!>, hp: i64, atk: i64, opp: i64 }
| full |> std/io:print.ln("outer full")
