---
type: belief
id: frag-a-p-recursive-fold-admits-certified-equality
provenance: holonomic gate v0 2026-10-02 — scripts/holonomic_gate.py proves
  equality between two differently-implemented koru folds (sum-of-odds ==
  squares) by certificate + bounded initial segment, no fuzzing involved
ts: 2026-10-02
---

# A fold whose step is polynomial in its state admits certified equality (belief)

A `#L`/`@L` label-fold is a coupled first-order recurrence over its state
record. When every field update is polynomial in the state fields (and the
guard is a single comparison), the observed field's iterate sequence is
P-recursive — and P-recursive sequences admit *decidable* equality: each
side certifies to a recurrence of order m via residual-zero verification,
the difference lives in a solution space of dimension at most
m_A + m_B (sum-closure bound), so vanishing on that bounded initial segment
— extended past every singular index where a leading coefficient vanishes —
is identical-everywhere.

This reframes what "checkable surface" means for the language. The compiler
checks shape and obligations; the gate checks *identity*: two programs can
be proven the same iterate sequence without either being run. The fragment
is deliberately narrow — arithmetic updates, resolvable literal init, one
comparison guard — and everything outside it gets a structured refusal, not
a weaker verdict. `CANDIDATE` (fitted but unverifiable) and
`NOT-FOUND-WITHIN-BOUNDS` are results, never refutations.

Two exact verification paths cover different shapes: affine-in-state
updates close the whole system (`s_n = T^n s_0`, sympy symbolic matrix
power — squares, triangular), while multiplicative updates verify by
generic-state residual with affine counters pinned to `init + c*n`
(factorial's `a_{n+1} = (n+2)a_n` telescopes exactly). What neither path
proves stays CANDIDATE — `@divTrunc` folds certify by fit but resist both.

## The test this leaves behind

The recursion is also the fuzzer tie-in: a GA that proposes fold bodies can
now receive *proofs* as fitness — certified program synthesis instead of
program + hope. The remaining honest debt is the meta-theorem itself:
uniqueness-from-initial-conditions for P-recursive sequences is implemented
in the gate but not yet a Lean lemma in `isar-proofs`; until it is, the gate
is an instrument that asserts its own bound.
