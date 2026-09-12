---
type: belief
id: frag-a-disposers-return-shape-is-its-unattended-ruling
provenance: 2026-09-12 — sqlite3's `release.row` wanted to be a pure-Koru impl
  (`~release.row -> row`, returning the released borrow) instead of a `|zig`
  marker, and the void-only candidacy gate in auto_discharge_inserter refused
  it. The first widening (any non-obligation `-> T` qualifies) red-boarded nine
  tests whose premise is "a value-returning consumer cannot fire unattended" —
  the drain-arm fixtures, the prefers-void pin, the rejection-diagnostic pin.
ts: 2026-09-12
---

# What a disposer may return is decided by who must take the return (belief)

Auto-discharge splices a bare call at a scope exit: nobody binds its result, no
arm answers a branch. So the candidacy question is really "can this event's
output be dropped without losing anything?" — and the answer splits the
return-type space three ways:

- **void** — nothing to drop. Always insertable.
- **`-> T<x>` released borrow** — a phantom token, not information. The disposer
  already did its work; the borrow is a convenience for explicit callers, and
  dropping it is the same as an unbound chain step. Insertable — this is what
  makes `~release.row -> row` a legal pure-Koru disposer.
- **plain value or `<x!>` live obligation** — somebody must take it. A value is
  output (`validate-response -> string` is a transform, not a disposer); an
  obligation is a new debt (`take -> *S<instance!>` is a transfer). Both still
  disqualify, exactly as the void-only rule said.

**The durable claim: the unattended ruling is a property of the return's
droppability, not of whether a return exists.** The first attempt at the
widening — "anything that isn't `<x!>` may be dropped" — treated a plain-value
return as droppable too, and nine tests objected in one voice: the drain-arm
machinery exists *because* a value-returning consumer cannot fire unattended,
and silently firing a transform at scope exit runs user logic nobody asked for
and discards its answer.

## Open

- Should a bare-return disposer's *inserted* call emit a discard-bind marker
  (`_ =`) the way explicit unbound calls do? Today the splice emits a flat
  invocation; a pure-Koru passthrough impl folds to nothing downstream, so the
  emitted call can vanish entirely. Harmless — but a reader of
  `output_emitted.zig` cannot see the discharge happened.
