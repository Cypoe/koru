// ga-cell: store__phantom
// ga-cell: branch_arm__effect_arm
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
     ! each _ |> std/store:query(items)
         ! query e |> std/io:print.ln("n {{ n:d }} v {{ e.v:d }}")
         | `(?<a>[A-Za-z]+) would lose (?<amt>[0-9]+) happiness units by sitting next to (?<b>[A-Za-z]+).` { a, amt: i64, b } |> std/string-map:get(m: names, k: a)
             | value ia |> std/string-map:get(m: names, k: b)
                 | value ib |> std/map:set(m: happy, k: ia * 16 + ib, v: 0 - amt)
                 | missing |> std/string-map:count(m: names): nb |> std/string-map:set(m: names, k: b, v: nb) |> std/map:set(m: happy, k: ia * 16 + nb, v: 0 - amt)
             | missing |> std/string-map:count(m: names): na |> std/string-map:set(m: names, k: a, v: na) |> std/string-map:get(m: names, k: b)
                     | value ib |> std/map:set(m: happy, k: na * 16 + ib, v: 0 - amt)
                     | missing |> std/string-map:count(m: names): nb |> std/string-map:set(m: names, k: b, v: nb) |> std/map:set(m: happy, k: na * 16 + nb, v: 0 - amt)
| full |> std/io:print.ln("outer full")
