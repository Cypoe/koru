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

**The luxury most languages don't have.** The industry default is
blanket-safe implementations — `Vector` synchronized always, `shared_ptr`
atomic refcount on every copy, `Arc` paying at the type level whether the
value ever crosses a thread — because a library cannot know its caller's
context. Koru's whole-program call graph does know: a program with no
`@threaded` root emits zero synchronization, and a threaded program pays
only in the locksets the parallel scope reaches. The price is opt-in per
program region — not per type, not blanket. The cost it stands on is
*located*, not diffuse: the unsafe surface is `|zig` bodies plus
`[threadsafe]` declarations — enumerable, reviewable, confined to the
module-authoring tier. Application code on the tor/flow surface cannot
express the escape (no opaque pointers, no skipped protocols, no false
claims), so it inherits correctness by construction — the stdlib gets
it right once and every program on top is free.

**v1 — four exclusive modes, one lock per call, emitted mechanically.**

The dirty flag is a compile-time fact on the decl (any-threaded-path-wins —
never duplicated trees, never call-time flags), computed by a forward
flood-fill over the `purity_checker`-shaped call graph from the `@threaded`
surface marker. Codegen reads flag × declaration:

- nothing declared → module mutex (process-lifetime static, coarse, safe —
  state that races usually lives in the same module's internals);
- `[lock(name)]` → that lockset's module-resolved mutex *instead of* the
  default — stacking buys ordering hazards and loses granularity;
- `[lock(param)]` where the name resolves to a resource binding → mutex on
  the instance, traveling with the object across modules — the one
  non-module case worth keeping (std/store is the canonical consumer);
- `[threadsafe]` → no lock — "I govern my own sync," a trusted claim
  (proc-land's `unsafe impl Send`), the escape hatch for anything the
  model doesn't cover — "why don't you just handle this yourself" is the
  correct answer to exotic cases;
- refusal tier (`[nothread]`/`[serial]`, spelling TBD) → compile error in
  the `@threaded` closure — locks can't save semantics that *are*
  serialization (ordered IO, yield, exclusive-ownership contracts).

Cross-module named locksets: refused — the instance-resolved form covers
the legitimate version.

**Deferred layer — obligation guards.** Multi-step atomicity
(read-check-write as one user sequence) is unexpressible in per-call
locks. The mechanism when a case demands it: `tor:begin`-style guards
minting a `<locked: res>` obligation, discharged through `commit` or
auto-discharged at extent end by the existing `auto_discharge_inserter`
traversal. Pass structure (sketched, unbuilt): obligation-check →
dirty-flood → guard-walk subtracting covered (site, lockset) pairs —
the discharge is keyed to the *mutex's resolved identity*, never the
tor's dirty flag, because tor-level uncoloring would let two unrelated
mutexes "cover" different halves of a set while serializing nothing.
A tor family may alternatively declare guard-required (`must be called
under <locked: res>`): auto-lock never emitted, unguarded calls refuse
with teaching.

**Mutex is less dubious than thread.** `worker.spawn` escaped lexical
bounds — unbounded lifetime, unanalyzable interleaving — correctly
dubious (threading.kz stays DUBIOUS as a surface; its *internals*
graduate to pool plumbing, which is what the ruling always said). A
mutex is scope-shaped: it can only shrink concurrency, never grow it,
and its guarded extent is statically delimited. `std/mutex` for a
self-scoped critical section is viable stdlib; the lockset-bound guard
is the heavier form.

**Rejected alternatives, and why.**

- *Send/Sync-style global traits* — no language-wide thread-safety
  taxonomy on values; tors own their resources' sync as a lifetime rule.
- *Ctx-style tree duplication* — sound for AST specialization, unsound
  for locking: an unlocked duplicate still writes the same physical
  resource and races the locked copy.
- *Context flag into the proc* — a call-chain-scoped flag leaks the same
  way (a single-threaded path overlapping threaded access in *time*
  skips the lock); strategy is carried by declarations instead.
- *Per-tor caller-side mutexes* — under-protective across tors sharing
  one resource, over-coarse across instances of one tor.

**Open rulings.**

- Cyclic calls under `@threaded` re-acquire a non-reentrant mutex —
  refuse with teaching (graph is static) vs recursive mutexes.
- Opaque-pointer escapes exit the lockset's enumerable membership —
  unsafe-boundary residue.
- norun/transform code is outside the call graph by construction.

**What would correct this.** A counterexample where lockset membership
is uncomputable (forces dynamic flags); a measured case where
module-default coarse locking sits hot (forces a different default);
a tor pattern needing multi-lock acquisition plus ordering; or a real
program that demands the deferred guard layer sooner than expected.
