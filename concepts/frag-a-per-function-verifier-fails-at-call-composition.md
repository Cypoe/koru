---
type: belief
id: frag-a-per-function-verifier-fails-at-call-composition
provenance: ccomp merge conclusion 2026-10-27 — 115_045's `pooled` flow timed
  out alive-tv at 60s AND at 300s; a minimal repro (alloc → bounds-checked
  write → read → print → free over a malloc'd struct-global, six internal
  calls) timed out identically, while every callee verified alone and the
  same caller verified in seconds with its callees external or always_inline
ts: 2026-10-27
---

# A per-function verifier's wall is the call composition, not the callees (belief)

alive-tv checks refinement function-by-function. The failure mode this creates
is asymmetric and easy to misread: every callee can verify alone while the
caller — straight-line code with no loop of its own — times out, because the
proof it must close composes the callees' memory effects in one query. The
measured instance: `pooled` = pool-alloc → stored write → bounds-checked read
→ print → pool-free over a global whose pointer `malloc` fills. Six calls,
zero loops, past the SMT budget at both 60s and 300s; a five-minute budget
did not move it. This is not "the query needs more time" — it is a query
shape the solver does not close, and raising `--smt-to` treats a boundary as
a budget.

The gate already knew the shape and had ruled on it: `scope:libcall-timeout`
is admitted only when every call in the region is a declared external —
"causation unproven" anywhere an internal call stands. That ruling is the
correct conservatism. What it costs is that a transform-minted call chain
over runtime-allocated state can be *semantically* fine yet unverifiable
per-function, and no amount of callee verification rescues the caller.

The fix that preserves the contract is on the emission side, not the gate:
**transform-minted glue is inlined anyway by every real compiler, so
declaring it `always_inline` is honest C, and inlining is exactly what
makes the caller's region local enough to verify.** Measured end to end:
marking the pool's `__grid_pool*` units and `__koru_at_<pool>` floor with
`__attribute__((always_inline))` (accepted silently by CompCert, forced by
clang at -O0) takes the same emitted program from `fail:timeout` to
`correct` — the surviving timeout is `__koru_unreachable`, which the gate
rightly scopes because every call in it is an external libcall. The stored
write stays a call and still verifies: the load-bearing inlines were the
malloc-owning units, not every unit in the chain.

Two cautions the measurement leaves behind:

- **Do not widen the scope rule instead.** Admitting "callers whose callees
  verified" as a scope class would let the one function that composes the
  verified pieces ride unverified — the composition is precisely where a
  wrong answer could live. The gate's "internal call → fail" line is the
  feature.
- **Inlining is not free to sprinkle.** Marking everything minted would
  merge loop-carrying units (sweep/for/walk drivers) into their callers and
  could move the timeout rather than remove it. The marked set is the
  pool's malloc-owning units and bounds floor — the functions whose
  composition provably grinds — not the whole `__grid_` namespace.

Open question: stores whose columns are heap-backed mint the same
alloc→write→free chain shape (`__store_*` units); no measured timeout yet,
but the same marking rule applies if one appears.
