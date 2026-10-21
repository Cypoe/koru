---
type: belief
id: frag-arm-words-discriminate-by-name
provenance: ccomp-line ruling pass 2026-10-21 — broadcast/select spelling proposals (Lars, fork review pending)
ts: 2026-10-21
tags: [channel, arms, spelling, select, broadcast]
related: [frag-an-arm-s-sigil-is-part-of-the-binding-s-type, frag-parts-are-flat]
---

# Arm words discriminate by name — select and broadcast reuse that idiom

Koru's arm grammar already discriminates by *name*: `! kind v` names a
message kind, `| ok | full | closed` name verb outcomes, `kind: payload`
labels a send. Two deferred channel spellings resolve to that idiom rather
than to new syntax — **ccomp-line proposals, fork review pending**.

**Per-flow select:** `std/channel:select(a, b)` returns a
channel-name-tagged sum discriminated by arms —
`| left v |> | right v |> | none |> | closed |>` — where the arm word names
the channel that fired and `closed` means *all* selected channels closed
(first-close would strand the other channel's values). The mechanism stays
the pinned pump-join (`699_010`): one participant whose `step` iterates the
selected rings — a widening, not a runtime `selectgo`. A `select {}` block
was rejected: new grammar for what arms already express.

**Broadcast:** `! each kind v |>`. The `each` word between sigil and kind
keeps the arm word a kind and marks the arm broadcast; `!!`/`!*` were
rejected — house style is words over symbols. Every `! each` arm copies each
firing of its kind; mixing with competing `!` arms on one channel is
coherent (workers split, listeners copy). Obligated kinds and borrows still
refuse — custody cannot be copied.

The honest cost: broadcast is *not* mechanism-free. Competing arms share
one pop cursor; each `each` arm wants its own read position (per-consumer
cursor or SPMC fan-out). The spelling is cheap; the cursor multiplicity is
the real build.
