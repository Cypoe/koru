---
type: belief
id: frag-an-honors-claim-is-an-induction-over-the-folds-own-edges
provenance: honors-claims rung, 2026-10-28 — the "goal absorption"
  step was designed around declared facets as seed premises until the
  fold's own entry bindings and goal-as-hypothesis proved sufficient
ts: 2026-10-28
tags: [koru, stdlib, spec, claims, prover, induction]
---

# An honors claim is an induction over the fold's own edges

A `std/spec:claim(atom: honors, on: step-tor) { "goal": "<linear cmp>" }` names a
loop invariant: the goal — one linear comparison over the step tor's input
fields — holds at every `#L` fold head. Its discharge needs no solver for
goals in general, because the fold provides both premises:

- **Base** — the `#L` head's entry invocation binds each field to an
  expression in *caller* scope. Renaming caller names to free variables and
  treating the bindings as equalities gives a meet that entails the goal
  exactly when the entry equations force it. Literal entries pin constants;
  open entries (naming caller fields) can still prove what the equations
  imply — and only that. Nothing is assumed about caller scope.
- **Step** — at every `@L` back-edge, the inductive hypothesis is the goal
  itself: `goal ∧ arm-guard ⊢ goal[substituted]`. Each conjunct is rows on
  the same variables; the judgment is infeasibility of `meet ∧ ¬goal'`
  through the spec-side Fourier–Motzkin engine.

`==` goals discharge per direction because `≠` is not one row. Anything the
grammar cannot read — non-if-dispatch impls, nested back-edges, non-linear
bindings — is `outside-P`, and a feasible countermodel is `unproven`, never
`refuted`.

The belief this corrects: "goal absorption" was imagined as needing the
subject's declared facets as seed premises. For a fold claim the fold
itself is the premise: its entry bindings and its own goal-as-hypothesis
close the induction without reaching outside the subject's scope.

Pinned by 675_010 (guard-suffices induction), 675_011 (IH load-bearing:
`i >= 0` survives `i+1` only because the goal is assumed), 675_012
(unproven: `i < limit` fails the `i+1` step), 675_013/014 (declaration
refusals).
