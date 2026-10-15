---
type: belief
id: frag-a-bound-on-what-may-be-touched-is-not-an-obligation-to-justify-the-touch
provenance: pass-graph `preserves` bounded which item kinds a write-back may touch for a full rung before anyone asked whether the transform had to justify a touch it was permitted. The audit's gap taxonomy (coverage / bound / obligation) named the missing axis; the `[obliges]` surface closed its first two decidable instances. Written 2026-10-15.
ts: 2026-10-15
---

# A bound on what may be touched is not an obligation to justify the touch

Permission and justification are different axes of a contract, and closing
one does nothing to the other. `preserves("!flow","!module_decl")` is
satisfiable in full by a transform that rewrites every flow in the program
into garbage — the bound is honored, the obligation simply does not exist.
A ledger that tracks bounds alone reports "within bounds" for a rewrite
nobody was ever asked to defend.

The fix is a separate claim surface, not a wider bound. `[obliges]`
predicates are claims about the write-back itself — `kind-stable` says
the collateral kind multiset is conserved, `matched-only` says every
removed non-site item was called — and like every claim on this branch
they are committed with the evidence an oracle needs to re-decide them,
not with a verdict to believe. A bound that never has to be justified is
an observation with extra syntax.

The secondary lesson is about granularity. Obligations enforced at
canonical-digest granularity make *clone drift* honest: an item the
transform clones but does not change still reads as touched if the clone
shifts the digest (module_decl does). The correct response is not to
narrow the obligation — it is to write back what you did not touch by
value and clone only what you changed. The obligation turned a silent
fidelity gap in the cloner into a visible forcing function, which is
what an obligation is for.
