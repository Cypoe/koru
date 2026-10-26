---
type: belief
id: frag-a-kernel-chain-sequences-ops-around-step
provenance: clbg_nbody kernel probe, 2026-10-23 — a `std/kernel:reduce` chained
  before `std/kernel:step` measured total=15 for masses [1,2] over 3 steps
  (accumulated per step) instead of total=3 (once over the initial state)
ts: 2026-10-23
tags: [koru, kernel, transform, semantics]
---

# An op's position relative to `std/kernel:step` IS its schedule (belief)

The kernel op list is sequential, not a flat bag `step` absorbs. An op
chained BEFORE the `std/kernel:step` invocation runs once over the pre-step
state; an op under a `| step |>` branch (including `|>` chains inside that
branch) runs once per step; an op chained PAST the step invocation runs once
over the post-step state. `KernelOp.position` (pre/step/post) records which
of the three the AST walk was in when the op was collected, and
`generateKernelOpsCode` emits position-grouped: pre ops, then `for (range) {`
+ step ops + `}`, then post ops.

The bug this corrects: ops were collected into one list with no position, and
every op emitted inside the step loop — so `reduce |> step` accumulated once
per step (a 4M-fold wrong result on the nbody probe) instead of once. Silent
wrongness, not a refusal — the worst kind. 390_131/390_132 pin the corrected
semantics; 390_116 already pinned that reduce INSIDE a `| step |>` branch
accumulates per step, which is what made position (not op kind) the right
cut.

Corollary that fell out of the same fix: a `| reduce |>` exit merges the
declared accumulators of EVERY reduce op in the chain, so pre-step and
post-step reductions exit through one `r` (`r.before`, `r.after`) — the
honest "measure, evolve, measure" spelling a physics kernel needs.

What would correct this belief: a nested-step semantics (a `| step |>` branch
inside a `| step |>` branch) — position is currently one axis; nesting would
make it a tree.
