---
type: belief
id: frag-the-callsite-cannot-spell-a-residual-case
provenance: corrected 2026-10-07 — Lars: "I think I was wrong when I made
  that call"; `|*` restored on the residual-arms branch, full suite green.
  Original recorded 2026-10-04 at the removal of `|?`.
ts: 2026-10-07
tags: [toolchain, outcome-model, parser, interpreter, consumer-spelling]
---

# The call site spells a residual — over the optional family only

Corrected. The prior record claimed a callsite residual *could never be
made honest* — that was never right. `|*` (respelled from `|?`, ~11 months
shipped before removal) is a compiled-surface arm that routes the callee's
unhandled *optional* terminal branches, and it carries the laws that make
it honest:

- **Optional family only.** `|*` catches `?`-marked terminal branches not
  named at the site. Required branches still must be armed by name —
  KORU022 fires with a residual present (355_013). The residual is the
  producer's grant consumed as a set, not a consumer-authored case: the
  set it routes is *enumerable from the declaration*, which is exactly the
  property that makes "computed by subtraction" honest rather than
  outcome-space authorship.
- **Never a discard.** `|* |> _`, `!* |> _`, and `|* Metatype _ |> _` all
  refuse (KORU026 pay-for-nothing; 210_081–083). An arm that binds nothing
  and does nothing is a refusal to handle, not a handler.
- **Testimony, not silence.** `|* Metatype e |>` binds a record whose
  `.branch` names what fired (355_010) — the arm can always say which
  outcome it caught; the "something optional happened but we can't say
  what" gap does not exist.
- **Panic stays loud.** `?!` branches are never routed to `|*` — their
  synthesized loud handling survives (355_014).
- **Not on the wire.** `|*` refuses at parse on the interpreted surface
  (440_020 answers `parse-error` inside a bridge turn; `eval` answers
  `validation-error`). There is no coverage check on that surface, so
  "optional-only" is unjudgeable there — and the original frag's sharpest
  argument survives intact: an honored wildcard on model-emitted source
  would absorb `unhandled-branch` itself, the channel the refusal loop
  reports on. The wire teaches named arms or omits; the residual is a
  compiled-surface construct because its legality is a compile-time fact.

## What the prior record got wrong — and what it got right

Wrong: the thesis that a residual invents a slot rather than filling one.
The slot is declared — by the producer's `?` marks, collectively. The
consumer isn't authoring outcome space; it is electing to handle the
declared-optional family as one arm instead of name by name.

Right, and kept: the evolution hazard. Producer adds `?debug` and every
existing `|*` re-maps silently — real, and accepted as the feature's
price: the producer opted those branches into the not-required family by
marking them, and the residual is the declared way to consume that family.
The hazard is on branches the producer already told consumers they need
not name.

Right, and kept: the exemption-signature observation. `|*` still requires
exemptions (coverage, ordering, emitter routing). The corrected reading:
it is a second grammar *position*, not an illegitimate one — the same
position `when` guards occupy (arms that don't name a branch outcome
directly).

## Spelling

Compiled callsite: `|*` glued — `|* b |>`, `|* Audit e |>`. Dead forms
refuse: `|?`, `| ?`, `!?`, `! ?` (KORU026/parse refusals; 210_315–317,
355_017–018), and spaced `| *` stays refused as the retired deref. The
literal branch name `*` remains armable only via backticks `` | `*` ``.
Declaration side unchanged: `?`/`?!` marks.

## Open

- Whether `|* M b`'s metatype qualifier should grow producer-declared
  `?`-families — today Transition/Profile/Audit are the closed compiler
  trio; a family-filtered residual waits on declared families.
- The metatype-registry move: the residual's record wants to live in the
  same declared registry as the tap metatypes rather than as an ad-hoc
  synthesized shape.
