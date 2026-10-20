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
- **Leases are spelled, and the node renews on activity — there is no
  heartbeat thread by design.** `claim`, `seize`, and `renew` take
  `ttl-ms` and write `until=<unix-ms>` on the record — a wall-clock
  deadline every process reads the same way (`std/time`'s `now` is
  process-relative monotonic, the wrong clock for a shared floor). An
  expired record is claimable: `fleetClaimExpired` runs the same
  serialized bump+commit `seize` does, so expiry is takeover by clock
  instead of by operator. `guard`/`owner`/`renew` all treat a lapsed
  lease as no lease. Node-side (evolved 2026-10-20):
  `std/node:new(..., lease-ms: T)` makes every claim carry a deadline;
  residency itself is the heartbeat — a member hit inside the
  deadline's last third re-acquires (renewing if still ours, evicting
  and answering `| held-by` if a takeover landed while the cell sat
  quiet), and `cellFlush` renews before its durable write. The stamp
  caches `until` so a live lease costs zero floor reads on lookup.
  A dead process stops renewing and its cells become claimable — the
  failure detector is the clock, exactly celld's ttl/3 cadence without
  a thread. 470_013 pins the lifecycle in-process; the cross-process
  receipt (`scripts/fleet_lease_two_process/run.sh`, evolved
  2026-10-20) proves it at the real boundary: process A leases and
  exits, a probe at ~400ms is refused `held-by`, and a later process
  B's bare member lookup takes the lapsed lease through the serialized
  takeover — no seize call, no operator — landing at epoch 2 with A's
  durable state intact.
- **Cross-process proven, claim and seize both raced.** The protocol
  survives a real process boundary (`scripts/fleet_two_process/run.sh`):
  process A claims, writes, and exits — the record outlives it; a fresh
  process B is refused `held-by nodea`, seizes at epoch 2, reads A's
  durable state, and writes under its own epoch. True concurrent
  racing is now measured too (evolved 2026-10-20,
  `scripts/fleet_race/run.sh`): 8 processes × 16 ids, exactly one owner
  per id, every loser naming the winner. The race immediately found a
  real defect: `createNew` publishes the record's *path* before
  `writeAll` lands its *bytes*, so a loser reading mid-window got a
  zero-byte record and answered `failed` for an id that was honestly
  held. `fleetAcquire` now re-reads with a bound in the CAS-loser arm.
  Concurrent `seize` is raced too (evolved 2026-10-20,
  `scripts/fleet_race/seize_race.sh`): 8 processes × 8 ids, and the
  lock dir did what it exists to do — per-id seized epochs came out
  unique and contiguous, every final record named the max-epoch
  seizer, and colliding seizers got `contended`, which is
  single-attempt: the caller must re-decide, the verb does not retry.
  The epoch counter remains advisory — the node-id half of guard
  carries correctness in racy windows; the epoch half carries it
  across release/reclaim. celld gets exact CAS from the object store;
  the filesystem gives atomic create and atomic rename but no
  compare-and-swap — the createNew→writeAll window is the concrete
  shape that difference took, and it is now a known, patched surface
  rather than a caveat.
- **The verbs are priced, and the price is the floor (evolved
  2026-10-20).** `tests/benchmarks/014_fleet_protocol` loops each verb
  60× against a zig baseline replaying the identical syscall sequences.
  Mins over 5 runs on a load-13 box — indicative, not claim-grade:
  owner ~14µs, claim+release ~330µs, renew ~240µs, seize ~420µs per op.
  The baseline lands within the same noise band — neither direction of
  the delta is claimed; what is measurable is that the runtime stack's
  overhead sits below the I/O noise floor on this box. The protocol is
  syscall-bound: custody's cost is the filesystem, not the dispatch.
  The numbers want a calm-machine re-run before they are cited anywhere.
- **Ownership is enforced at the identity boundary and the write
  fence now gates the write path.** `std/node` consults the record on
  every identity-changing path (evolved 2026-10-20): `spawn` and member
  lookups acquire before residency, `retire` deletes only what the node
  owns, and a foreign record answers `| held-by` — a mandatory
  compile-time arm, so owned-elsewhere is a program decision, not
  silence. A never-existing id stays `| not-found` and claims nothing;
  a dormant foreign cell is `| held-by`, never activated. The fence
  itself (evolved 2026-10-20): the granted epoch rides on the cell as a
  `FleetStamp`, and `cellFlush` presents it to the record — a stale
  owner's write dies at the flush, celld's void-the-zombie semantic.
  470_011 pins it: seize at epoch 2, the stale capture runs (compute
  is not fenced — the write is) and the new owner reads pre-seize
  state. Still open: no routing, and a stamped cell's fenced write is
  silent — `std/fleet:guard` is where a program can check, an arm on
  the write is not.

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
