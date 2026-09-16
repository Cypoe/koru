// Test: a clamp facet on a packed member leaf normalizes at the insert
// boundary — `left.health: 250` under `health: Health & clamp(0, 100)`
// stores the saturated value (100), and bounds on the same field judge
// the post-clamp result (`>=0` passes on what was stored, not what was
// typed). Two placements of one proto keep independent columns.
//
// Expected: runs clean — `left 100 right 20`: the out-of-range write is
//           coerced into the facet's interval, the in-range one untouched.
import std/proto
import std/refine
import std/store
import std/io

std/proto:i64(Health)

std/proto(Limb) {
    health: Health
}

std/refine(Limb) {
    health: Health & clamp(0, 100) & >=0
}

std/store:new(body, capacity: 8) { left: Limb, right: Limb }

std/store:insert(body) { left.health: 250, right.health: 20 }
| row r |> std/io:print.ln("committed {{ r:d }}")

std/store:query(body)
! query e |> std/io:print.ln("left {{ e.left.health:d }} right {{ e.right.health:d }}")
