---
type: belief
id: frag-transform-stages-sequence-producer-consumer
provenance: transform_pass_runner.zig Stage + ctx/component ordering
  collision — probe_ctx_order.k (2026-10-19)
ts: 2026-10-19
---

# Transform ordering is staged: consumers must sit behind producers

A whole-program transform that *reads* synthesized decls cannot share a
stage with the transforms that *produce* them — within a stage the
fixed-point applies the first site found, so ordering is positional and
a consumer placed earlier in source than its producer sees a program
that does not yet contain what it needs.

Measured: `std/ctx` (`[pre]`) resolving a prop on a `component`-generated
tor worked only because the `component` site preceded the ctx flow in
source; reversing the order refused `KORU080` — while the same program
with an explicit argument compiled fine, proving decl resolution is
order-free and the fragility was the transform's lookup timing.

The fix is a stage, not a workaround: `pre → pre_late → main → post`.
`pre_late` exists for exactly this shape — consumer transforms that need
producer output (component decls, store schemas) but must still complete
before `main`-stage `claims_descendants` transforms (`preorder`,
`sweep`, `query`, `rule`, `kernel:init`) lift raw subtrees. A consumer
at `main` would break the other direction: a `std/ctx` step inside a
claimed arm must already be injected when the claimer fires.

The pipeline runs `pre` and `pre_late` together in `run-pre-transforms`
(`compiler.stages.kz`), before the per-call template pass, so consumer
output is ordinary AST that expands normally. The all-stages Phase 2.4
run re-walks all four stages in order; `@pass_ran` makes already-fired
sites no-ops.
