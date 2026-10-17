---
type: belief
id: frag-verdicts-want-redeciders-definitions-want-singletons
provenance: building verify/semantics/FlowKernel.lean next to verify/witness/WitnessCheck.lean — two Lean artifacts that look symmetric and are not; the asymmetry is the point
ts: 2026-10-17
---

# Verdicts want re-deciders; definitions want singletons (belief)

The verification branch carries two Lean surfaces that look like the same
move and are opposites:

- `WitnessCheck.lean` is a **re-decider**: the compiler prints witness
  claims, the oracle independently derives the verdict again. Two
  implementations, and their possible disagreement is the mechanism — a
  forged or drifted claim fails because the second decider does not
  follow the first.
- `FlowKernel.lean` is a **singleton**: the mechanized flow-graph
  evaluator does not re-decide anything. It IS the semantics. There is
  deliberately no second evaluator to cross-check it against, because a
  semantics that exists twice is not checked — it is two candidates and
  a coincidence.

**The durable claim: independence is the doctrine for claims, not for
definitions.** Re-deciding a *verdict* buys you a wall — disagreement is
a refusal surface. Re-deciding a *definition* buys you nothing — two
evaluators that agree today are two places the semantics can drift
tomorrow, and when they disagree you have learned there is a bug
somewhere but not which artifact is wrong, because neither is the
referent. The referent for a definition has to be singular: one
evaluator, kernel-checked, against which every implementation (koruc's
runtime, the C emitter's compiled output) is a *claim* to be verified —
and claims get re-deciders.

This is why the fuel-bounded evaluator in FlowKernel ships with
`evalNode_mono` rather than a second engine: more-fuel-never-flips is
what makes the bound a resource limit instead of a second semantics.
If fuel could change a decided answer, the fuelled evaluator and the
unfuelled "true" semantics would be the two-candidates problem all over
again, with the disagreement hidden inside one file.

## Where this could be wrong

- A singleton semantics is only as good as its fit to the implementation
  it claims to define — **measured, not merely predicted.** A
  clause-by-clause audit of FlowKernel against `comptime_eval.zig` found
  seven real divergences, all model-side (void-dispatch refusal,
  catchall tagged-dispatch, `and`/`or` short-circuit, truncating `/` `%`,
  floored `@mod`, `++` vs `+`, lazy `@as`): the kernel WAS a clean model
  of a slightly-wrong language, and every fix moved the model toward the
  implementation — divergence was a bug with a referent, exactly as
  predicted. `FlowCheck.lean` re-decides `[flow-eval]` whole-program
  claims end to end, and the emit leg has now landed:
  `comptime_eval.zig` serializes one claim per interpreter-consumed
  walk under `std/witness:enforce` (graph + entry args + fuel bound +
  result-or-refuse + thunk oracle leaves), with `[flow-eval-skip]`
  markers for walks outside the kernel subset so silence is never
  ambiguous. Real claims re-decide MATCH; a hand-forged edit to a real
  claim's result MISMATCHes — the disagreement surface works on live
  output, not only on fixtures. `310_141` pins the round trip.
- There is a defensible middle: two mechanized semantics with a proved
  equivalence (a definitional and a denotational reading, as in textbook
  PL formalizations). That is one semantics stated twice and *proved*
  equal — the proof is what makes it safe. The claim is against two
  unproved-equal definitions, not two presentations.
