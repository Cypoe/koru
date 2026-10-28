---
type: belief
id: frag-a-guards-connective-decides-which-arm-owns-its-rows
provenance: guard-connective rung, 2026-10-29 — `if(A and B)` parsed,
  emitted, and ran while the claims fence refused it as "not a single
  linear comparison"; widening the reader meant deciding which arm may
  assume what, and De Morgan decided what is representable at all.
ts: 2026-10-29
tags: [koru, stdlib, spec, claims, prover, guard, connectives]
---

# A guard's connective decides which arm owns its rows

The impl dispatch's guard is premise mass, and a meet of rows can only
hold a conjunction — so the top-level connective is what decides which
arm gets fed:

- **`A and B`** — the then-arm takes every conjunct's rows. The else-arm
  takes *nothing*: `¬(A ∧ B)` is `¬A ∨ ¬B`, a disjunction of half-planes
  no row set can spell. A weaker meet stays sound — it may fail to
  prove, it cannot prove wrong.
- **`A or B`** — the mirror image, and the profitable side is the else:
  `¬(A ∨ B)` IS `¬A ∧ ¬B`, a conjunction of negations — every disjunct
  negates into rows the else-arm may assume. The then-arm takes nothing.
- **no connective** — today's shape: then takes the comparison's rows,
  else takes its negation (with the usual honesty splits: `==` gives the
  then both directions, `!=` the else, and the unrepresentable side
  nothing).
- **mixed or nested connectives** — `a and b or c`, or an `or` inside a
  conjunct's parens, has no one-level reading. outside-P, naming the
  piece: the fence reads one level and routes the rest to guard rather
  than guess a meet.

The asymmetry is the doctrine: rows are conjunctive, so `and` feeds the
then and `or` feeds the else — the *unprofitable* side is not an error,
it is silence. The widening is pure premise construction: every consumer
(arm meets, produce contracts, honors steps, rank candidates) inherits
it at once because they all draw from the same `claimsArmMeets` reading.

Open edge: `&&`/`||` are read identically to `and`/`or` in the fence,
but emission passes guard text through verbatim and Zig refuses `&&` —
a `&&` program can earn a claim verdict and still fail codegen. That is
an emitter-honesty gap in the guard's own lowering, not a claims
question; the same leak exists today for `&` (bitwise surface chained
on comparisons).
