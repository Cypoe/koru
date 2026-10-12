---
type: belief
id: frag-a-head-effect-arm-partitions-into-a-context-free-fn
provenance: 2026-11-04 — frontier-surface chasing mail_merge's "proc-effect arm sees module scope only" report: the raw Zig error ('tag' not accessible from inner function) became KORU207, pinned 400_208
ts: 2026-11-04
---

# A head `!` arm on an impl flow partitions into a context-free fn (belief)

An impl flow whose HEAD call invokes an effectful decl partitions its `!` arms
into a synthesized `Handlers_*` struct (visitor_emitter phase 3b), passed
`comptime` to the call. Fns inside a struct see module scope only — the
implementing tor's params are locals of the enclosing handler fn and cannot
cross. A reference used to survive shape checking and die in emitted Zig
(`'x' not accessible from inner function`); KORU207 now refuses at check time
with the teaching hint (stage in a store, or move the call off the head).

The wall is exactly: **impl-flow head + real effectful decl**. Everything else
keeps scope by construction:

- Mid-chain `!` arms inline into the frame — the enclosing handler's locals
  survive.
- `[template]` procs (`for`/`if`/`capture`) lower by substitution into the
  consumer frame — the arm never partitions.
- Names bound INSIDE the arm subtree emit in the arm fn's own frame — a param
  re-bound inside the arm is legal, not a shadowing dodge.
- Pre-label folds take `emitFlow`, not the partition.

This is the same lesson as the sweepbody naming frag, one axis up: the
synthesized unit's scope is decided by WHERE it lands, not where it was
written — and every place that boundary is crossed invisibly, a param's name
dies without a Koru-level reason.

Pin: 400_208 (`EXPECT error[KORU207]`, `NOT_CONTAINS output_emitted.zig` —
the refusal must fire before any Zig exists).
