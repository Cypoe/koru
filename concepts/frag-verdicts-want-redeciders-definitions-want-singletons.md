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
  walk under `std/witness:enforce` (graph + entry args + fuel
  certificate + result-or-refuse + thunk oracle leaves), with
  `[flow-eval-skip]`
  markers for walks outside the kernel subset so silence is never
  ambiguous. Real claims re-decide MATCH; a hand-forged edit to a real
  claim's result MISMATCHes — the disagreement surface works on live
  output, not only on fixtures. `310_141` pins the round trip. The fuel
  field is a certificate in the strong sense: the walker counts one
  increment per kernel `run` call along the derivation spine, so the
  emitted number IS the measured proof depth — not a padded bound. The
  move that made this cheap: you don't need ISAR's static
  `sufficient_fuel_correct` to stop guessing — when the instrumentation
  is isomorphic to the checker's cost model, the walk reports its own
  depth, and every undercount fails loud (fuel exhaustion is `none`,
  never a wrong yes). What remains unproved is the isomorphism itself —
  corpus-pinned, not theorem-pinned. The checker itself now carries its
  spec: `WireOk` is the wire relation, and `checkLine_{sound,complete,
  reject,none}` prove the executable answers MATCH only inside it —
  the ISAR `step?`/`IStep` shape. Two honest discoveries from that rung:
  `Float` has no lawful decidable equality (IEEE `+0.0 == -0.0`), so the
  relation's verdict-equality *is* the checker's `==` — attempting
  `decide (· = ·)` was the two-candidates trap in miniature, proposing a
  stricter equality the corpus never agreed to; and the unproved residue
  is decoder fidelity — `WireOk` talks about the *decoded* claim, and a
  misdecoding `sxArm` would verify the wrong claim consistently. That
  lemma belongs to `FlowDialect`'s encode/decode preservation.
  The re-decider shape then grew past the verdict: A.5 put the flow's
  residue arms on the wire, so the kernel re-decides the *observable*
  too — `renderObservable` re-dispatches the result into the residue
  (`spliceResidue`'s own rule, not a second reading) and renders the
  print nodes, and `--cref` compares that derivation against the
  emitted C's actual `__koru_stdout_write*` sequence. The graph→C seam
  is thereby checked per instance — the emitter's runtime observable
  is verified against an independent derivation of it, which is the
  translation-validation half of the channel. `310_142` pins the pair:
  verdict MATCH and `cref: refined` on one compile. What A.5 does NOT
  yet do: refuse the *absence* of residue coverage — a claim with
  `(residue)` arms the renderer can't read just fails the marked test,
  but nothing checks that every emitted flow function got a claim
  (the zip is count-strict per corpus, which is the current guard).
- There is a defensible middle: two mechanized semantics with a proved
  equivalence (a definitional and a denotational reading, as in textbook
  PL formalizations). That is one semantics stated twice and *proved*
  equal — the proof is what makes it safe. The claim is against two
  unproved-equal definitions, not two presentations.
