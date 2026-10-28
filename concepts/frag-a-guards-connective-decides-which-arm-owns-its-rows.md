---
type: belief
id: frag-a-guards-connective-decides-which-arm-owns-its-rows
provenance: guard-connective rung, 2026-10-29 — `if(A and B)` parsed,
  emitted, and ran while the claims fence refused it as "not a single
  linear comparison"; widening the reader meant deciding which arm may
  assume what, and De Morgan decided what is representable at all.
  Evolved same week: the one-level reading measured one rung too small —
  an arm's premise is not rows-or-nothing but a SET of case-meets, the
  guard's own DNF, so mixed and nested connectives judge rather than
  refuse.
ts: 2026-10-29
tags: [koru, stdlib, spec, claims, prover, guard, connectives]
---

# A guard's premise is a case set, not a row set

The impl dispatch's guard is premise mass, and a meet of rows can only
hold a conjunction — so a guard with a disjunction in it cannot be one
meet. It can be a SET of them: the guard's DNF, one case-meet per
clause, and the discharge is asked under every clause of the arm that
produced the edge. De Morgan pushes `not` through the tree for the
else side — `or`↔`and` flips, atoms negate at the leaves — so BOTH
arms eat:

- **`A and B`** — then gets the single clause `{A ∧ B}`; else gets
  `{¬A}` and `{¬B}` — two cases, each a half-plane row set.
- **`A or B`** — then gets `{A}` and `{B}`; else gets the single clause
  `{¬A ∧ ¬B}`.
- **mixed and nested** — `a and b or c`, or an `or` inside parens,
  distribute the same way: `or` binds loosest (Koru's own precedence),
  DNF does the rest. What used to be "the fence reads one level" was
  the refusal of a case split it had not yet learned to ask for.
- **infeasible cases are free** — `{i > 0, i < 0}` is a clause FM finds
  empty: a case that cannot happen discharges vacuously, and asking it
  costs nothing. The budget that IS honest to refuse is the clause
  count — DNF is exponential in the worst shape, so the fence caps an
  arm and names the cap rather than blow up.

The verdict rule is per-case: a step, a contract, a rank must clear
EVERY clause of the producing arm — `unproven` when any case can
violate it, which is exactly the soundness the one-level fence bought
with silence. Every consumer (arm meets, produce contracts, honors
steps, rank candidates — case rows are candidate sources too) draws
from the same `claimsArmMeets` reading, so the widening landed in all
of them at once. And the 675_026/027 pins are the measure: guards the
old fence could only route to outside-P now earn `unproven` and
`proven` verdicts — real judgments.

The emit-door half of the story: `&&`/`||` are Koru spellings Zig
cannot eat, and the lowering door (`rewriteZigExpr`'s keyword-binop
level) respells them to `and`/`or` with the author's spacing riding —
a `&&` program earns its claim verdict AND compiles. What remains raw
passthrough: `&` is not a Koru operator at all (nothing in
`expression_parser` owns it), so `j > 0 & i > 0` still reaches Zig
verbatim and fails *loudly* — a backend diagnostic, never silent
divergence; whether bitwise surface deserves a real grammar level is
a later ruling.

Still outside the guard fence: `not` as a surface operator (De Morgan
exists only inside the reader, not as user syntax), non-linear leaves,
`!=` on the positive side (a disjunction — it contributes no rows, so
the case it lands in just carries less), and the then/else two-arm
dispatch shape itself.
