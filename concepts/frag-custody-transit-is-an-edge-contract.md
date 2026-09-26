---
type: belief
id: frag-custody-transit-is-an-edge-contract
provenance: channel/obligation design session 2026-09-25 — the MPMC-vs-obligation question turned out to be misposed; the corrected matrix fell out over six hours of design discussion
ts: 2026-09-25
tags: [koru, obligations, channel, rings, threading, design-ruling]
---

# Custody transit is a per-edge contract (custody × topology × substrate), never a per-type trait (belief)

The ruling reached this session: whether an obligation may cross a vessel
boundary (channel send/recv, store insert/take, ring enqueue/dequeue) is
computed *per transit edge* from three facts the compiler already sees —

- **custody class of the value**: owned obligation (`<live!>`-family) may
  transit; borrow (`<state>`-family) refuses at every boundary because the
  frame dies before delivery; plain data is always free.
- **delivery semantics of the vessel**: exactly-once delivery is safe at ANY
  consumer count — competition pops to exactly one winner and every
  receiving arm is statically checked to discharge. Broadcast would mint N
  claims on one linear resource and is refused; it was never built.
- **substrate physics of the edge**: Zig's shared heap carries owned
  pointers across threads fine (the ring's own release/acquire slot
  protocol *is* the happens-before); a JS reference cannot cross a worker
  heap no matter how clean the ledger is — refuse at the edge.

This is deliberately NOT Rust's model: `Send`/`Sync` are global per-type
assertions the programmer maintains. Here the same proto is legal on one
edge and refused on another, because the question is per-site, not
per-type. The consumer-count analysis Lars proposed collapses further:
the count doesn't gate *custody* at all (competition is exactly-once) —
it selects *substrate* (MPMC → MPSC → SPSC → plain buffer → direct
handoff is a perf ladder, not a legality ladder) and it detects the one
unsafe pattern, broadcast.

## The poison law

`send`'s verdict IS the custody transfer point: `ok` consumes the
binding's obligation into the vessel; `full`/`closed` leave it with the
producer, who still must discharge. `| some v` mints the obligation fresh
at the winning arm. Pin family: 699_022–029.

## Measured current state (the gap the pins hold open)

Channels today do **copy-in, dispose-at-source**: `send` moves the plain
bytes, the producer's binding keeps the obligation, and auto-discharge
fires at the producer's scope — so a proto carrying a real handle would
compile into a poisoned-resource bug (the ring's copy holds a dead fd).
The obligation ledger catches misuse at the consumer arm (KORU030), which
means the failure is loud but the diagnostic blames the wrong site.

## Constraints that keep this honest

- Channel kind vocabularies accept proto *registry names* only — pointer
  elements are structurally unspellable, so the deconstruction rule Lars
  demanded is already enforced by the grammar, not by a lint.
- `frag-region-colouring-cannot-see-its-regions` measured that spawned
  work bodies are opaque host function pointers — context coloring (the
  enforcement for "store writes can't come from another thread") only
  propagates where Koru text reaches. Until spawn bodies are Koru, the
  enforcement pin (690_350) sits behind that wall.
- `frag-an-obligation-is-unary-every-boundary-is-relational` bounds what
  obligations can express at all: custody (unary) is reachable; ordering
  between two in-flight values is not. The transit design stays inside
  the reachable class on purpose — that is WHY it is buildable.

## Where this could be wrong

- If exactly-once delivery ever gets a counterexample (a pop path that
  duplicates, a drain that drops), competition+obligations is no longer
  free and the consumer-count gate comes back — that would correct this.
- If a fourth custody class appears (shared/refcounted — deferred
  deliberately), the owned/borrow/plain trichotomy needs a branch.
- The JS substrate claim assumes worker heaps stay private; a
  SharedArrayBuffer-based object transit would relax the substrate clause.
