// Test: the mailbox — `held-by` is no longer a dead end. A refused caller
// posts a turn to `.fleet/inbox/<id>`; the owner of record drains it under
// the lock and the `! mail` arm executes it. The mailbox belongs to the
// cell: mail posted while the id is unowned waits for the next owner, and
// a stale node's drain answers `held-by` and consumes nothing.

import std/io
import std/fleet
import std/node
import std/cell
import std/proto
import std/runtime

std/proto(room_state) {
    hits: u32
}

pub tor touch { k: u32 } -> u32
touch -> k + 1

std/runtime:register(scope: "cell") {
    touch(5)
}

std/fleet:reset(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_014_fleet_mail/world")
  | cleared |> std/io:print.ln("slate cleared")
  | failed e |> std/io:print.ln("reset failed {{ e:s }}")

std/node:new(alpha, scope: "cell", world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_014_fleet_mail/world", capacity: 8)
std/node:new(beta, scope: "cell", world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_014_fleet_mail/world", capacity: 8)

// Leftover state may be owned by either node (a passing run ends with
// alpha holding both records) — both retire so the slate is clean no
// matter which; identical arm text keeps the oracle deterministic.
std/node(alpha)
| node f |> std/node:retire(f, id: "room-mb")
  | retired |> std/io:print.ln("slate cleared")
  | held-by o |> std/io:print.ln("slate cleared")
  | absent |> std/io:print.ln("slate cleared")

std/node(beta)
| node f |> std/node:retire(f, id: "room-mb")
  | retired |> std/io:print.ln("slate cleared")
  | held-by o |> std/io:print.ln("slate cleared")
  | absent |> std/io:print.ln("slate cleared")

std/node(alpha)
| node f |> std/node:spawn(f, id: "room-mb", cell: room_state)
  | spawned b |> std/io:print.ln("alpha spawned room-mb")
  | resident |> std/io:print.ln("resident")
  | held-by o |> std/io:print.ln("alpha refused: held by {{ o:s }}")
  | refused |> std/io:print.ln("refused")

// Beta is refused the cell — so it posts the turn to the mailbox instead.
std/node(beta.room-mb)
| cell c |> std/io:print.ln("beta activated (BUG)")
| held-by o |> std/fleet:send(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_014_fleet_mail/world", id: "room-mb", from: "beta", body: "touch(k: 5)")
    | posted |> std/io:print.ln("beta posted mail 1 to {{ o:s }}")
    | failed e |> std/io:print.ln("send failed {{ e:s }}")
| not-found |> std/io:print.ln("beta: not-found")

std/fleet:send(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_014_fleet_mail/world", id: "room-mb", from: "beta", body: "touch(k: 2)")
  | posted |> std/io:print.ln("beta posted mail 2")
  | failed e |> std/io:print.ln("send failed {{ e:s }}")

// The owner drains: each mail is a turn — run it against the resident cell
// and commit its result. Order is send order.
std/fleet:drain(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_014_fleet_mail/world", id: "room-mb", node: "alpha")
! mail m |> std/io:print.ln("mail from {{ m.from:s }}: {{ m.body:s }}")
  |> std/node(alpha.room-mb)
    | cell c |> std/cell:run(c, source: m.body)
      | result r |> std/cell:capture(c, shape: room_state)
        ! as s |> std/cell:captured { hits: s.hits + 1 }
      | error e |> std/io:print.ln("turn failed: {{ e.kind:s }}")
    | held-by o |> std/io:print.ln("alpha lost room-mb mid-drain: {{ o:s }}")
    | not-found |> std/io:print.ln("room-mb vanished")
| done n |> std/io:print.ln("alpha delivered {{ n:d }} mails")
| held-by o |> std/io:print.ln("alpha drain refused: {{ o:s }}")
| free |> std/io:print.ln("room-mb unowned")
| contended |> std/io:print.ln("drain contended")
| failed e |> std/io:print.ln("drain failed {{ e:s }}")

std/node(alpha.room-mb)
| cell c |> std/cell:get(c, field: "hits")
  | value v |> std/io:print.ln("alpha reads hits={{ v.int:d }}")
  | unset u |> std/io:print.ln("hits unset")
  | unknown-field e |> std/io:print.ln("no field")
| held-by o |> std/io:print.ln("lookup refused: {{ o:s }}")
| not-found |> std/io:print.ln("lost")

// A stale node cannot drain another owner's mailbox.
std/fleet:drain(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_014_fleet_mail/world", id: "room-mb", node: "beta")
! mail m |> std/io:print.ln("beta got mail (BUG)")
| done n |> std/io:print.ln("beta delivered {{ n:d }} (BUG)")
| held-by o |> std/io:print.ln("beta drain refused: {{ o:s }}")
| free |> std/io:print.ln("beta: free")
| contended |> std/io:print.ln("beta: contended")
| failed e |> std/io:print.ln("beta drain failed {{ e:s }}")

// The mailbox outlives an ownership gap: post while unowned, the next
// owner takes delivery.
std/fleet:send(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_014_fleet_mail/world", id: "gap-mb", from: "beta", body: "ping")
  | posted |> std/io:print.ln("gap mail posted while unowned")
  | failed e |> std/io:print.ln("gap send failed {{ e:s }}")

std/fleet:claim(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_014_fleet_mail/world", id: "gap-mb", node: "alpha", ttl-ms: 0)
  | claimed e |> std/io:print.ln("alpha claimed gap-mb epoch={{ e:d }}")
  | held-by o |> std/io:print.ln("gap-mb held by {{ o:s }}")
  | failed e |> std/io:print.ln("gap claim failed {{ e:s }}")

std/fleet:drain(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_014_fleet_mail/world", id: "gap-mb", node: "alpha")
! mail m |> std/io:print.ln("gap mail from {{ m.from:s }}: {{ m.body:s }}")
| done n |> std/io:print.ln("gap delivered {{ n:d }}")
| held-by o |> std/io:print.ln("gap drain refused: {{ o:s }}")
| free |> std/io:print.ln("gap-mb unowned")
| contended |> std/io:print.ln("gap contended")
| failed e |> std/io:print.ln("gap drain failed {{ e:s }}")

// A drain on an id nobody has ever owned answers free.
std/fleet:drain(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_014_fleet_mail/world", id: "never-mb", node: "alpha")
! mail m |> std/io:print.ln("phantom mail (BUG)")
| done n |> std/io:print.ln("never delivered {{ n:d }} (BUG)")
| held-by o |> std/io:print.ln("never held by {{ o:s }}")
| free |> std/io:print.ln("never-mb: free")
| contended |> std/io:print.ln("never contended")
| failed e |> std/io:print.ln("never drain failed {{ e:s }}")

std/node(alpha)
| node f |> std/node:drain(f): n |> std/io:print.ln("alpha drained {{ n:d }}")
std/node(beta)
| node f |> std/node:drain(f): n |> std/io:print.ln("beta drained {{ n:d }}")
