---
type: belief
id: frag-linear-judgment-over-integers-tightens-strict-rows
provenance: terminates-prover rung, 2026-10-27 — real-valued FM
  refuted the canonical `limit - i` loop with a fractional countermodel
  (`i=0, limit=0.5` satisfies `i < limit` while `limit-i-1 < 0`); integer
  execution cannot produce it
ts: 2026-10-27
tags: [koru, stdlib, spec, refine, linear, fourier-motzkin, prover]
---

# Real-complete linear feasibility is not integer-correct at strict boundaries (belief)

Fourier–Motzkin elimination is complete over the reals — but every field
the refine/claims engine judges is integer-typed. A strict row
`Σc·x < b` over integer fields is exactly `Σc·x <= b-1`; leaving it
strict admits fractional countermodels that no execution can produce.
`linFeasible` tightens at load time, which is what turned the canonical
`limit - i` rank provable where untightened FM reported `unproven`.

Tightening is one-directional honesty: it can only certify *more*
infeasibility on the true (integer) domain, never less, so a wrong
verdict is impossible — at worst a genuinely non-integer-shaped system
reports `unproven`.

Placement is part of the ruling: the linear grammar (`parseLinExpr`,
`splitLinCmp`) and engine (`linFeasible`) live in `std/spec`, not
`std/refine`, because `koru_spec` is in the always-emitted set — the
claims pass runs in every backend — while `koru_refine` is opt-in via
`import`. A shared linear engine placed in an opt-in module silently
gates the pass on a user import; ownership follows emission guarantee,
not topical similarity.
