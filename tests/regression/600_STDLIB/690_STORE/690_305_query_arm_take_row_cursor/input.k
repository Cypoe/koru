// A `! query` arm can TAKE its matched row — the query-road twin of
// 690_031 (which pins `rule` + `! row`). Two pieces had to meet here:
//
//   1. Addressing: `take(arena[e])` rewrites the bare row binding `e` to a
//      row HANDLE minted from the sweep cursor — the body event receives a
//      dense index, but `store[...]` resolves handles. Before this, `e`
//      leaked through as a raw identifier: `undeclared identifier 'e'`.
//
//   2. Sweep shape: a taking body swap-removes the last row into the freed
//      slot, so the loop re-checks the SAME index when len shrinks — the
//      removal-tolerant `while`, not the fixed-range `for`. Row order
//      [5, 50, 8] is the adversarial case: taking 5 swaps 8 into slot 0,
//      already passed; the sweep must revisit it. Both go; 50 survives.
//
// Found via koru-libs games/ponkatris: `collect` takes a crystal on its
// sensor hit — the take lives under a `! query` arm, not a `! row` rule.

import std/io
import std/store

std/store:new(arena, capacity: 8) { hp: i64 }

std/store:insert(arena) { hp: 5 }
| row _ |> _
| full |> _
std/store:insert(arena) { hp: 50 }
| row _ |> _
| full |> _
std/store:insert(arena) { hp: 8 }
| row _ |> _
| full |> _

std/store:query(arena)
    ! query e when e.hp <= 10
        |> std/store:take(arena[e])
            | item i |> std/io:print.ln("took {{ i.hp:d }}")
