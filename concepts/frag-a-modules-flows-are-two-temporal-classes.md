---
type: belief
id: frag-a-modules-flows-are-two-temporal-classes
provenance: 2026-09-13 — 115_018 leak after 291efff7c moved every imported-module
  flow ahead of the entry's; branch main
ts: 2026-09-13
---

# A module's top-level flows are two temporal classes, not one (belief)

291efff7c moved `module_runtime_flows` ahead of the entry's flows on the
strength of a true premise — a module's top-level flows are its
initialization, and the importer's code must run against a world that exists
(ponkatris: `sim/index.k` seeds the bodies store at top level; the tick loop
ran first and printed nothing). The premise was right; the classification
was wrong. A module's flow list carries a second temporal class: its END.
`store.new.kz` appends the owned-column teardown flow LAST on the contract
"appended items land at the end of program.items, so it runs after every
user flow — before the leak check." Moving all module flows to the front
ran teardown on an empty store, then let the entry's flows insert values
nobody freed — `115_018` leaked, caught only by the zig lane's leak check.

Schedule module flows by role, not by provenance: `[teardown]`-annotated
flows collect into `module_teardown_flows` and emit after the entry's
flows, still inside `koru:start`/`koru:end`. Anything a transform appends
as end-of-program must mark itself — position alone stopped being the
contract the moment init flows jumped the queue. The entry module's own
teardown needs no annotation handling: appended-last lands it at the end
of the entry's own flow list, which already runs before `koru:end`.

Open question: should teardown ordering be LIFO across modules (the module
imported last tears down first)? Today the flows run in declaration order.
No test pins it; if two modules' stores ever hold cross-owned pointers it
becomes load-bearing.
