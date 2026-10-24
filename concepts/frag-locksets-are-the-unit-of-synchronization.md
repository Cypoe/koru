---
type: belief
id: frag-locksets-are-the-unit-of-synchronization
provenance: session 2026-10-24 — threading-design digression off the `! each` work
ts: 2026-10-24
tags: [koru, threading, lockset, tor, proc, phantom]
---

# The lockset is the unit of synchronization; `@threaded` reachability dirties the whole set (belief)

**The ruling.** Synchronization in Koru is never user-visible. The unit of
locking is the *lockset* — the accessors that share state — and reachability
from any `@threaded` (parallel-scope) call chain dirties the entire set:
every member emits the lock, including members reached only through
single-threaded paths. A lock taken by only some accessors protects nothing;
a synchronization protocol lives between accessors on a shared object, never
at a call site or inside a call chain.

**The tier model — exactly one lock per call, modes exclusive.**

- Nothing declared → the module mutex (coarse, safe default: state that
  races usually lives in the same module's internals).
- `[lock(name)]` → that lockset's mutex *instead of* the module default —
  stacking the module lock on top serializes named-set callers against the
  whole module (losing the granularity the name bought) and creates a
  two-lock acquisition-order surface for no correctness gain. The
  declaration asserts "my shared state is this set."
- `[lock(param)]` where the name resolves to a resource binding → the mutex
  lives on the instance and travels with the object across modules — the
  only form that protects a resource whose representation can be touched
  through another module's procs.
- `[threadsafe]` → no lock — "I govern my own sync." The unsafe-layer
  contract: a proc's declaration is a trusted claim (proc-land's `unsafe
  impl Send`), covering the governed families — store's atomics and
  partitioned-row contract (frag-store-kernel-self-parallelizes-bit-
  identically) — whose finer protocols the machinery could never infer.

**Rejected alternatives, and why.**

- *Send/Sync-style global traits* — ruled out: no language-wide
  thread-safety taxonomy on values. Tors own their resources'
  synchronization as a lifetime rule; the analysis is per-resource and
  per-lockset, not per-value-type.
- *Ctx-style tree duplication* — sound for type/const specialization (the
  specialized thing is the AST) but unsound for locking: an unlocked
  duplicate still writes the same physical resource and races the locked
  copy. Any-threaded-path-wins makes "dirty" a compile-time fact instead —
  the tor's emitted code always locks and every caller runs the locked
  form. Cost: an uncontended lock for pure-single-threaded callers —
  accepted.
- *A context flag passed into the proc* — the flag's only added value was
  strategy choice, and the declaration surface already carries strategy.
  A call-chain-scoped flag leaks the same way duplication does: a
  single-threaded path overlapping a threaded one in *time* skips the
  lock on the shared object. So the compiler emits the lock mechanically
  from the dirty-set, and declarations are the override.
- *Per-tor caller-side mutexes* — wrong granularity in both directions:
  different tors on one resource don't serialize (under-protective); all
  callers of one hot tor on disjoint resources do (over-coarse).

**Bespoke guards stay bespoke.** Atomicity across user steps
(read-check-write as one sequence) is not expressible by per-call locks —
a tor family that needs it declares its own phantom obligation (a
`<locked>` guard minted by e.g. `std/store:begin`, discharged through
`commit`). Phantom machinery is language infrastructure; each tor family
authors its own contract — the `:`-in-destructure doctrine: the language
stays permissive, consumers own semantics.

**Open rulings.**

- Cyclic calls under `@threaded`: a recursive or A→B→A cycle re-acquires
  a non-reentrant mutex — deadlock. The call graph is static, so refusal
  with teaching is cheap; recursive mutexes are the alternative.
- Opaque escapes: a resource handed out as a raw pointer exits the
  lockset's enumerable membership — the borrow's own contract is the
  sync there, or it is unsafe-boundary residue.
- Reachability needs the compiler's call graph to be complete — norun /
  transform code is excluded by construction.

**What would correct this.** A counterexample where lockset membership
is uncomputable (resources reachable only through unclassifiable paths —
forces dynamic flags after all); a measured case where module-default
coarse locking sits on the hot path (forces a different default tier);
or a tor pattern where one-lock-per-call is provably insufficient
(forces multi-lock acquisition plus an ordering rule).
