---
type: belief
id: frag-an-event-fires-once-per-apply
provenance: ruling session with Lars 2026-10-24 — settled the 690_017/019/020 unit-of-observation trio
ts: 2026-10-24
---

# An event fires once per apply; its payload is shaped like the write (belief)

A store event — watch, interceptor arm, DI `! ?persist` — fires once per
APPLY, carrying a payload shaped like the write that committed: scalar
write → `{old,new}` scalars (degenerate case), compound-field write → the
whole vector, batch insert → the plural rows delta.

The axiom underneath: the apply is the atomicity unit, so per-row/per-lane
fires would let observers see states that never existed at any instant —
observational integrity is the axis, not speed, though the honest default
is also the fast one (no per-row dispatch inside a fused cascade). Per-row
and per-lane access is a handler-side concern — iterate the plural payload
(`rows |> each`), or project through a stripe/query. Observation is not
projection.

Deferred with intent, not neglected: a granularity override on the
declaration — possibly a *binding*-annotation lane (`r[mutable]` precedent;
an arm like `! persist[per_row]`), whether tors should express delivery
conventions there. Parked until a consumer exists; the `Type[ann]` lane
shipped the same day (see [[frag-type-position-brackets-are-compiler-annotations]]).

Still open inside 690_017: connection purity (may the handler hold a live
connection across the apply — the ORM-showcase collision) and the install
surface (arms on `watch`? on `link`?). Neither blocks the payload law.
