// Test: leases make "dead" a clock fact. A claim with ttl-ms writes an
// `until` deadline on the owner record; while it is live a foreign claim
// answers held-by, and past it the record is claimable — the takeover runs
// seize's serialized bump so the winner lands at a fresh epoch and the
// lapsed owner's guard fences. renew extends the deadline owner-only.

import std/io
import std/fleet
import std/time

std/fleet:reset(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_012_lease_expiry_renewal/world")
  | cleared |> std/io:print.ln("slate cleared")
  | failed e |> std/io:print.ln("reset failed {{ e:s }}")

std/fleet:claim(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_012_lease_expiry_renewal/world", id: "room-42", node: "node-a", ttl-ms: 250)
  | claimed e |> std/io:print.ln("node-a claimed epoch={{ e:d }}")
  | held-by o |> std/io:print.ln("a refused: held by {{ o:s }}")
  | failed e |> std/io:print.ln("claim failed {{ e:s }}")

std/fleet:claim(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_012_lease_expiry_renewal/world", id: "room-42", node: "node-b", ttl-ms: 0)
  | claimed e |> std/io:print.ln("node-b claimed early epoch={{ e:d }}")
  | held-by o |> std/io:print.ln("node-b refused while lease live: {{ o:s }}")
  | failed e |> std/io:print.ln("claim failed {{ e:s }}")

std/time:sleep-ms(ms: 400)

std/fleet:claim(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_012_lease_expiry_renewal/world", id: "room-42", node: "node-b", ttl-ms: 0)
  | claimed e |> std/io:print.ln("node-b took expired lease epoch={{ e:d }}")
  | held-by o |> std/io:print.ln("node-b refused after expiry: {{ o:s }}")
  | failed e |> std/io:print.ln("claim failed {{ e:s }}")

std/fleet:owner(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_012_lease_expiry_renewal/world", id: "room-42")
  | owned-by o |> std/io:print.ln("record now says {{ o:s }}")
  | free |> std/io:print.ln("room-42 free")
  | failed e |> std/io:print.ln("owner failed {{ e:s }}")

std/fleet:guard(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_012_lease_expiry_renewal/world", id: "room-42", node: "node-a", epoch: 1)
  | owner |> std/io:print.ln("node-a still owner")
  | fenced e |> std/io:print.ln("node-a fenced at epoch={{ e:d }}")
  | free |> std/io:print.ln("record gone")
  | failed e |> std/io:print.ln("guard failed {{ e:s }}")

std/fleet:claim(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_012_lease_expiry_renewal/world", id: "room-99", node: "node-a", ttl-ms: 200)
  | claimed e |> std/io:print.ln("node-a claimed room-99 epoch={{ e:d }}")
  | held-by o |> std/io:print.ln("room-99 held by {{ o:s }}")
  | failed e |> std/io:print.ln("claim failed {{ e:s }}")

std/fleet:renew(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_012_lease_expiry_renewal/world", id: "room-99", node: "node-b", ttl-ms: 800)
  | renewed |> std/io:print.ln("node-b renewed a foreign lease")
  | held-by o |> std/io:print.ln("node-b renew refused: {{ o:s }}")
  | free |> std/io:print.ln("nothing for node-b to renew")
  | failed e |> std/io:print.ln("renew failed {{ e:s }}")

std/fleet:renew(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_012_lease_expiry_renewal/world", id: "room-99", node: "node-a", ttl-ms: 800)
  | renewed |> std/io:print.ln("node-a renewed its lease")
  | held-by o |> std/io:print.ln("node-a renew refused: {{ o:s }}")
  | free |> std/io:print.ln("nothing for node-a to renew")
  | failed e |> std/io:print.ln("renew failed {{ e:s }}")

std/time:sleep-ms(ms: 250)

std/fleet:claim(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_012_lease_expiry_renewal/world", id: "room-99", node: "node-b", ttl-ms: 0)
  | claimed e |> std/io:print.ln("node-b took room-99 early epoch={{ e:d }}")
  | held-by o |> std/io:print.ln("room-99 still held: {{ o:s }}")
  | failed e |> std/io:print.ln("claim failed {{ e:s }}")

std/time:sleep-ms(ms: 700)

std/fleet:claim(world: "tests/regression/400_RUNTIME_FEATURES/470_FLEET/470_012_lease_expiry_renewal/world", id: "room-99", node: "node-b", ttl-ms: 0)
  | claimed e |> std/io:print.ln("node-b took room-99 after lapse epoch={{ e:d }}")
  | held-by o |> std/io:print.ln("room-99 held by {{ o:s }}")
  | failed e |> std/io:print.ln("claim failed {{ e:s }}")
