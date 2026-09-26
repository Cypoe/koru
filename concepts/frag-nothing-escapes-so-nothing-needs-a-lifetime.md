---
type: belief
id: frag-nothing-escapes-so-nothing-needs-a-lifetime
provenance: channel/obligation design session 2026-09-25 — Lars's realisation mid-conversation; the three-mechanism argument (scope + custody + refusal) that replaces lifetime annotations
ts: 2026-09-25
tags: [koru, lifetimes, obligations, design-ruling]
---

# Koru has no lifetime annotations because nothing in the grammar can escape (belief)

Lifetimes exist in Rust because `&'a T` is a first-class value that can be
stored in structs, returned, and sent — so the compiler needs an
annotation language to bound how long the referent must outlive the
reference. Koru's grammar has no escape hatch, and every "outlives"
question is answered by *where the thing was declared*:

- **borrows** (`<state>`-family phantoms) are scope-bound by construction:
  they cannot be stored in a vessel (the ring's element check refuses
  them), cannot cross a channel, cannot outlive their frame — the frame
  IS the lifetime, so there is nothing to name.
- **vessels** (stores, channels) are top-level *declarations with names*,
  never values that get passed — program-scoped, `'static` by
  construction. The dominant source of lifetime machinery elsewhere
  simply doesn't arise.
- **owned values** are covered by custody, not lifetimes: "alive until
  discharged" is the obligation ledger's job already
  (`frag-an-obligation-is-a-liveness-interval`).

The consequence is a design theorem rather than a feature: the
outlives-relation is derived from program shape the same way parallelism
is derived from topology — computed metadata, never authored annotation.

## The load-bearing caveat

The theorem holds **because** the refusals hold. The ring's element check,
the channel's proto-name-only kind vocabulary, and the absence of
first-class vessel values are what keep references from escaping. Any
relaxation — borrows in store rows, channels as passable values, a
locking construct that shares mutable state across threads — reintroduces
escaped aliasing, and lifetimes come back whether we want them or not.
The refusal IS the lifetime system. This is the falsifiable edge: if a
legal Koru program is found where a reference outlives what scope +
custody + refusal can bound, this belief is wrong, not merely incomplete.
