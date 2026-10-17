---
type: belief
id: frag-terminality-collapses-pairwise-congruence
provenance: the 2026-10-17 conversation that routed the emit leg — recognizing that isar-proofs' terminal InvariantLayer is the N²→N answer to emitter congruence, not a nicer formalization
ts: 2026-10-17
---

# Terminality is the N²→N collapse (belief)

Emitter congruence is **pairwise without a kernel object**. Every new lane
multiplies the checks: Zig↔C, Zig↔LLVM, C↔LLVM, and each per-instance
refinement check pays again per artifact, forever. A.5's graph→C checker is
exactly this shape — decidable, automatic, catches drift today, and never
stops paying.

isar-proofs proves its `InvariantLayer` quotient **terminal** in a category
of closed computational dialects (`Dialect` = carrier + encode/decode/eval +
preservation law). If koru flows become a view — a `FlowDialect` instance —
then each emitter pays *one* preservation proof and cross-lane congruence is
**derived through the quotient**, not checked per artifact. That is the
collapse: N lanes × N lanes of pairwise checks become N preservation proofs
into one kernel object.

**The durable claim: per-instance checking and terminality are not in
competition.** The checks buy coverage while the proof debt accrues; the
factorization retires the debt *class*. Neither substitutes for the other —
per-instance refinement is what survives contact with real programs today,
and the dialect route is what stops the quadratic bleed once the lanes
multiply.

The Futamura-adjacent precision that matters here: the correspondent
question is not Jones optimality ("did specialization remove an interpretive
overhead layer" — no interpreter is being removed) but **"is this view
observationally equal to the quotient"** — `ObservationRegime`/`∼𝒪` and the
terminality morphisms in isar-proofs are already that theory, frozen at
exactly the right abstraction.

## Where this could be wrong

- A `FlowDialect` instance is real work — koru's flow carrier must encode,
  decode, and preserve evaluation through the layer. If the carrier can't
  hold flow semantics faithfully, the instance never lands and pairwise
  checks remain the whole answer.
- ISK is the instrumental fragment isar-proofs used to prove anything at
  all, not the target — the koru view presents its own carrier and decodes
  into the anchored quotient; encoding flows *into SKI* is the mistake the
  phi2 leg already made once.
- Even landed, the instance covers only the kernel subset — effects, stores,
  transforms stay outside the quotient the way they stay outside
  FlowKernel's evaluator.
