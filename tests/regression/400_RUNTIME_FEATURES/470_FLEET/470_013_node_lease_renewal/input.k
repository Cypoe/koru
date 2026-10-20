// Test: node-side leases. `std/node:new(..., lease-ms: T)` makes every
// claim the node writes carry a deadline, and residency itself is the
// heartbeat — a member hit inside the deadline's last third renews it,
// a quiet node's claim lapses and becomes claimable, and a resident
// whose lease was taken over answers `| held-by` on its next lookup
// instead of serving a zombie cell.

import std/io
import std/fleet
import std/node
import std/cell
import std/proto
import std/runtime
import std/time

std/proto(room_state) {
    visits: u32
}

std/runtime:register(scope: "cell") {
}

std/fleet:reset(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_013_node_lease_renewal/world")
  | cleared |> std/io:print.ln("slate cleared")
  | failed e |> std/io:print.ln("reset failed {{ e:s }}")

std/node:new(alpha, scope: "cell", world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_013_node_lease_renewal/world", capacity: 8, lease-ms: 600)
std/node:new(beta, scope: "cell", world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_013_node_lease_renewal/world", capacity: 8, lease-ms: 600)

// Leftover state may be owned by either node (a passing run ends with
// beta holding the record) — both retire so the slate is clean no
// matter which; identical arm text keeps the oracle deterministic.
std/node(alpha)
| node f |> std/node:retire(f, id: "room-lp")
  | retired |> std/io:print.ln("slate cleared")
  | held-by o |> std/io:print.ln("slate cleared")
  | absent |> std/io:print.ln("slate cleared")

std/node(beta)
| node f |> std/node:retire(f, id: "room-lp")
  | retired |> std/io:print.ln("slate cleared")
  | held-by o |> std/io:print.ln("slate cleared")
  | absent |> std/io:print.ln("slate cleared")

std/node(alpha)
| node f |> std/node:spawn(f, id: "room-lp", cell: room_state)
  | spawned b |> std/io:print.ln("alpha spawned room-lp")
  | resident |> std/io:print.ln("resident")
  | held-by o |> std/io:print.ln("alpha refused: held by {{ o:s }}")
  | refused |> std/io:print.ln("refused")

std/node(alpha.room-lp)
| cell c |> std/cell:capture(c, shape: room_state)
  ! as s |> std/cell:captured { visits: s.visits + 41 }
  | captured f |> std/io:print.ln("alpha committed visits={{ f.visits:d }}")
| held-by o |> std/io:print.ln("lookup refused: held by {{ o:s }}")
| not-found |> std/io:print.ln("lost")

// The live lease blocks beta's activation path — dormant or not.
std/node(beta.room-lp)
| cell c |> std/io:print.ln("beta activated early")
| held-by o |> std/io:print.ln("beta refused while lease live: {{ o:s }}")
| not-found |> std/io:print.ln("beta: not-found")

std/time:sleep-ms(ms: 500)

// ~500ms in: inside the last third of alpha's 600ms lease. The member
// hit renews it — no explicit verb, residency is the heartbeat.
std/node(alpha.room-lp)
| cell c |> std/io:print.ln("alpha touched room-lp (lease renews)")
| held-by o |> std/io:print.ln("alpha lost its own resident: {{ o:s }}")
| not-found |> std/io:print.ln("alpha: not-found")

std/time:sleep-ms(ms: 300)

// t≈800: past the ORIGINAL 600ms deadline — still held only because the
// resident hit renewed it.
std/node(beta.room-lp)
| cell c |> std/io:print.ln("beta activated early")
| held-by o |> std/io:print.ln("beta refused past original deadline: {{ o:s }}")
| not-found |> std/io:print.ln("beta: not-found")

std/time:sleep-ms(ms: 600)

// t≈1400: alpha went quiet; the renewed deadline (~1100) lapsed.
// Beta's member lookup takes the expired lease and activates.
std/node(beta.room-lp)
| cell c |> std/cell:get(c, field: "visits")
  | value v |> std/io:print.ln("beta activated after lapse, reads visits={{ v.int:d }}")
  | unknown-field e |> std/io:print.ln("no field")
  | unset u |> std/io:print.ln("unset")
| held-by o |> std/io:print.ln("beta still refused: {{ o:s }}")
| not-found |> std/io:print.ln("beta: not-found")

// Alpha's stale resident answers held-by on its next lookup — the lease
// it held was taken over, the zombie is evicted.
std/node(alpha.room-lp)
| cell c |> std/io:print.ln("alpha still resident (BUG)")
| held-by o |> std/io:print.ln("alpha evicted its stale resident: held by {{ o:s }}")
| not-found |> std/io:print.ln("alpha: not-found")

std/node(alpha)
| node f |> std/node:drain(f): n |> std/io:print.ln("alpha drained {{ n:d }}")
std/node(beta)
| node f |> std/node:drain(f): n |> std/io:print.ln("beta drained {{ n:d }}")
