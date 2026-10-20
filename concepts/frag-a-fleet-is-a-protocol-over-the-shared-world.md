---
type: belief
id: frag-a-fleet-is-a-protocol-over-the-shared-world
provenance: std/fleet construction, 2026-10-20 — first chip of the
  cross-machine layer, built the same day `std/fleet`→`std/node` was
  renamed to free the name for exactly this
ts: 2026-10-20
---

# A fleet is a protocol over the shared `world`; the directory is the bucket (belief)

celld's load-bearing simplification is that the fleet needs no coordinator
because the bucket *is* the coordinator — conditional object-store writes
are the only consensus it ever runs. Koru's `world` was already that
bucket without naming it: `<world>/<id>/state.kv` is the shared durable
namespace every node in a fleet would see. `std/fleet` makes the protocol
explicit: ownership is an atomic `createNew` on
`<world>/.fleet/owners/<id>` (the conditional write), takeover is
tmp+rename under a lock dir at a bumped epoch (`seize`), and the fence is
`guard` — a holder presents its node-id + granted epoch and both must
still be on the record or the write is refused.

The design discovery is that **the fence needs a counter that outlives
the record.** `release` deletes the owner record; if the epoch died with
it, a fresh claim would reissue epoch 1 and a stale epoch-1 token would
pass `guard` as live. `<world>/.fleet/epochs/<id>` is never deleted, so
epochs are unique per id forever — the stale-writer window closes
structurally, not by timing. 470_006 pins this: claim, release, reclaim
at epoch 2, stale epoch-1 token fenced.

celld's own invariant ordering carried over: the check sits at the write
(`guard`), not at dispatch. The 838–848 ports proved the obligation shape
compiles; `470_FLEET` proves the same decision runs against a real shared
floor — deterministic, no clocks, no sockets. Six tors, all leaves:
`claim`, `owner`, `seize`, `release`, `guard`, `reset`.

## What this does NOT claim

- **No routing.** `held-by`/`owned-by` tell you who holds an id, but
  there is no way to send it a turn — `std/net` is a refusal surface.
  Routing waits on a wire, or on a mailbox-dir simulation that has not
  been written.
- **No leases.** `seize` is operator-decided takeover; nothing expires on
  a clock. A TTL field in the record plus a monotonic `std/time` read is
  the obvious next chip, and it is a chip, not a design problem.
- **Race windows exist.** The epoch counter is advisory under true
  multi-process concurrency — two racing claims can compute the same
  candidate epoch, and only the createNew serialization makes that
  harmless. The node-id half of the guard check is what carries
  correctness in those windows; the epoch half carries it across
  release/reclaim. celld gets exact CAS from the object store; the
  filesystem gives atomic create and atomic rename but no
  compare-and-swap, so the honest limit is stated, not hidden.
- **Ownership is enforced at the identity boundary; writes are not yet
  fenced.** `std/node` consults the record on every identity-changing
  path (evolved 2026-10-20): `spawn` and member lookups acquire before
  residency, `retire` deletes only what the node owns, and a foreign
  record answers `| held-by` — a mandatory compile-time arm, so
  owned-elsewhere is a program decision, not silence. A never-existing
  id stays `| not-found` and claims nothing (probe precedes claim),
  and a dormant foreign cell is `| held-by`, never activated — the
  split-brain refusal. Still open: `captured` does not `guard`, so a
  stale owner can still write state after losing the record — the
  epoch fence exists but does not yet gate the write path.

## What would correct this belief

- A race the two-half guard cannot catch — e.g. a stale writer whose
  node-id still matches the record because the reclaim re-granted the
  same id to the same node at a lower epoch (impossible while the counter
  never shrinks; a counter reset path would reopen it).
- A second coordination substrate (a real object store, SQLite) that
  changes which primitives are atomic — the protocol would re-map, and
  "the directory is the bucket" would become one binding of the idea,
  not the idea itself.
- A requirement for symmetric handoff (owner-assisted migration) that
  seize-as-takeover cannot express — that is a protocol extension, and
  it would argue the surface should grow verbs, not that the model is
  wrong.
