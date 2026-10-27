---
type: belief
id: frag-a-folds-own-guards-supply-its-rank-candidates
provenance: rank-inference rung, 2026-10-28 — `terminates` with no
  declared rank needed a synthesis story that invents nothing: the
  subject's own arm guards are bounds the dispatch already proved.
ts: 2026-10-28
tags: [koru, stdlib, spec, claims, prover, rank, inference]
---

# A fold's own guards supply its rank candidates

Declared rank asked the author to spell what the guard already says:
`while i < limit, step i+1` terminates at rate `limit - i`. Inference
makes that explicit — a normalized guard row `Σc·x ≤ b` is a bound the
subject's own dispatch proved, so `b − Σc·x` is a rank *candidate*; every
candidate faces exactly the discharge a declared rank faces, and the
first to clear every back-edge is named in the verdict with its
canonical spelling (`inferred rank 'limit - i'`).

Two consequences of doing it this way rather than with a dedicated
synthesis engine:

- **Inference is enumeration + the same oracle.** The prover shares one
  discharge path (`claimsRankTry`) between declared and inferred rank —
  an inferred proof can never be weaker than a declared one, because it
  literally is one. What inference adds is only WHERE the rank comes
  from.
- **Failure stays honest.** When no candidate discharges — the `!=`
  guard is the canonical case, where the fence cannot express "i never
  overshoots" — the verdict is `unproven` with the first candidate's
  failure named, never a guessed rank and never `refuted`.

The `rank` field being optional (rather than a second atom) keeps the
vocabulary honest: `terminates` means the same thing whether the author
spells the measure or asks the fold to supply it.
