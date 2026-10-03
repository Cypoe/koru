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
is deliberately narrow — arithmetic updates, literal or caller-parametric
init (fitted on a prime specialization, verified for all parameter
values), one comparison guard — and everything outside it gets a
structured refusal, not
a weaker verdict. `CANDIDATE` (fitted but unverifiable) and
`NOT-FOUND-WITHIN-BOUNDS` are results, never refutations.

Two exact verification paths cover different shapes: affine-in-state
updates close the whole system (`s_n = T^n s_0`, sympy symbolic matrix
power — squares, triangular), while multiplicative updates verify by
generic-state residual with affine counters pinned to `init + c*n`
(factorial's `a_{n+1} = (n+2)a_n` telescopes exactly). What neither path
proves stays CANDIDATE — `@divTrunc` folds certify by fit but resist both.

The extraction boundary is part of the trusted base. A certificate is a
claim about the *extracted* model — so the gate's soundness lives as much
in what the extractor refuses as in what the math proves. First-match
searches over the whole file, a record arm assumed to be the transition,
re-dispatch args assumed to be an identity map (`@L(s.acc, s.n)` is a
*different* transition, not a spelling), and a `when` guard dropped
instead of modeled are all ways to certify a program that was never
written. The rule: anything the model cannot see faithfully must refuse
— a stop condition you cannot extract is one you would certify away.
A `when` on the single continue arm is the guard itself; `when` anywhere
else, a second record arm, a second dispatch arm, or a comparison the
parser can't read all REFUSED.

## The test this leaves behind

The recursion is also the fuzzer tie-in: a GA that proposes fold bodies can
now receive *proofs* as fitness — certified program synthesis instead of
program + hope. The meta-theorem debt is paid: uniqueness from initial
conditions is proven in `isar-proofs` (`PRecursive.lean`,
`eq_of_satisfiesRecurrence_of_init`, non-singular case by strong
induction), and the D-finite → P-recursive direction of the
generating-function bridge is in (`HolonomicBridge.lean`). Open: the
converse direction and singular-point uniqueness — agreement at indices
where the leading coefficient vanishes replaces the missing constraint.
