---
type: belief
id: frag-a-scoped-lookups-null-is-a-silent-feature-switch
provenance: the unikernel Orisha build refusing `run_event.handler(.{ .port = port })` with "expected 2 argument(s), found 1"; the subflow head had resolved its sibling-module target to null and that null had turned off a lowering nobody was asking it about
ts: 2026-08-08
---

# A scoped lookup's `null` is a feature switch, and every later gate wired to it inherits a scope it never chose (belief)

The subflow head in `visitor_emitter` resolved the event it invokes against the
ENCLOSING MODULE's items. That was a deliberate, correct choice when it was
made, for the question it was made to answer: *does this target declare a
mutable branch, so the result wants `var` rather than `const`?* A miss answering
"no" is harmless — the emitter writes `const`, which is what it would have
written anyway.

Then effect branches arrived, and the same `?*const EventDecl` became the gate
on a second, unrelated question: *does this target declare `!` branches, so the
caller's arms must be lifted into a synthesized Handlers struct and passed as a
second argument?* Nothing was rewritten. The new code read the old variable,
because the old variable already held exactly the thing it needed.

**The scope came along with it, unnamed and unreviewed.** A call into a sibling
submodule — Orisha's `serve`, written inside the `orisha` module, over
`orisha/pump:run` — misses the enclosing module's item list, so the lookup is
null, so the effect partition never runs, so the `! arrived` arm is lowered as
an ordinary terminal switch prong against a call still written `handler(...)`.
The event's real signature takes two parameters. Zig says so, at the call site,
about a line the emitter wrote.

## Why it is worth a belief rather than a one-line fix

The fix is one `orelse`. The shape is not.

A lookup that returns an optional is a *query*; a gate that branches on that
optional is a *policy*. When one variable serves both, the query's scope silently
becomes the policy's scope — and the policy's author never sees the decision,
because there is no decision written down to see. There is only a name that
reads as "the event I am calling."

The failure mode is asymmetric in the worst direction. For the ORIGINAL question
the miss is a no-op, so nothing surfaces, so the narrow scope survives every test
that would have caught it. For the LATER question the same miss drops a required
argument, and the complaint lands two stages downstream in generated Zig.

So the test on any reused resolver is not "is this lookup correct" but **"is
every question now branching on it asking about the same universe?"** If one
consumer only needs the local module and another needs the program, they are two
lookups wearing one name.

## The sibling this is a member of

[[frag-resolution-anchors-on-the-flows-home-module]] holds the other half: there
the anchor was *which module counts as "here"*, and it also failed closed and
silently. Same organ, different joint — that one is a walk carrying a stale
notion of its own position, this one is a query whose scope was inherited by a
consumer that never asked for it. Both produce a pass that runs, reports
nothing, and changes nothing.

## The reroute this defect had already paid for

The consumer had, before the fix, been reshaped around this: Orisha's
`~proc orisha:handler|zig` in the unikernel example carries a comment explaining
that the `response { … }` constructor "garbles the record", so the example uses
a proc instead. That is a workaround for a *different* live defect, written down
as a property of the library. The shape outlives the memory of why it exists;
this one is still there, still uncommented as a compiler bug.

## Second landing — the effect partition itself (2026-10-07)

The belief fired again, twice in one diff, when Campfire's `/cable` wired
`orisha/pump:ws-closed = cable:dropped(fd) ! gone-room …` — a CROSS-MODULE claim
whose head calls an effect-carrying tor:

- `emitFlow`'s two head-site lookups (`pre_label` typing and the effect
  partition) still read `ctx.ast_items` only. The module-blind `findEventDeclByPath`
  misses what `findEventDeclForEmission` — written for exactly this — resolves
  through `program_items`. Both sites now use it.
- The cross-module claim-impl branch in `visitor_emitter` never had the
  partition at all: it wrote `handler(.{ … })` raw and lowered the `!` arm into
  the result switch, naming a variant `Output` does not carry. It now runs the
  400_175 dance — partition, `emitHandlersStruct`, `terminal_conts` to the
  switch — that its module-local twin already had.

Same lesson, second proof: the fix that lands is one line; the shape is that
every *new* emission path re-implements the question and inherits whichever
scope is nearest. `400_207` pins the claim-impl shape.

## Open

- The remaining raw `handler(.{` sites are fewer now — the two emitFlow lookups
  and the claim-impl path are closed. The continuation-step emitters were
  already covered (`inlineEffectfulEligibility`, the 400_198 fix); what remains
  unpinned is any FUTURE emission path that asks "does this tor have `!`
  arms" against module-local items. The defect is not a list of sites — it is
  the reflex of writing the question against `ctx.ast_items` at all.
- Call-site variant mangling turned out to be REDUNDANT today, not missing: the
  event-decl emitter already swaps the default `handler` body for the selected
  variant, so `handler` and `handler__unikraft` are byte-identical. Two
  mechanisms achieve one selection, and only one of them was ever the design.
  Which one is meant to be authoritative is not settled anywhere I could find.
