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

- **Routing is spelled — as a mailbox, not a wire (evolved
  2026-10-20).** `.fleet/inbox/<id>/` belongs to the cell, not the
  node: `send` posts a turn file (tmp+rename, multi-producer safe),
  `drain` delivers it owner-side under the lock — guarded like the
  write fence, ordered by send-time, at-least-once (file deletes only
  after the arm returns). `held-by` is now a redirect, not a refusal.
  Mail survives takeover and ownership gaps — proven in-process
  (470_014: two turns delivered in order, one posted to an unowned id
  arrives at the next owner) and cross-process
  (`scripts/fleet_mail_two_process`: B refused, posts, exits; A wakes,
  drains, executes both turns, visits 41→43). Building it surfaced a
  defect now pinned: a spawned-but-unflushed cell had an owner record
  but no `state.kv`, and the member-miss probe answered `not-found`
  without consulting the record — owned-and-bodiless now answers
  `held-by` via `fleetForeignLiveOwner` (live lease only; an expired
  record stays claimable). Still open: no real wire (`std/net` stays a
  refusal surface), drain is caller-driven — no background courier,
  and a fenced write is still silent.
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
  Mins over 5 runs on a calm box (load ~4, 2026-10-20): owner ~10µs,
  claim+release ~194µs, renew ~164µs, seize ~270µs per op — vs baseline
  ~6µs / ~206µs / ~158µs / ~261µs. The write verbs land within ~4% of
  the raw-syscall floor and the read probe shows ~3.7µs of stack
  (dispatch + parse): the protocol is syscall-bound — custody's cost
  is the filesystem, not the runtime. A first run under load-13 read
  ~2× these numbers, which is the noise band these figures sit above.
- **The first real celld comparator exists (evolved 2026-10-21).**
  celld 0.6.2 runs locally via the distroless docker image
  (`celld dev --host 0.0.0.0` + a mounted linux-arm64 esbuild —
  `dev` bundles with esbuild and the image ships none). Its own
  `examples/counter` IS the counter-grain workload: get → n++ → put
  per request. Sequential durable turns: ~4.6ms p50, ~208 rps; at 8
  connections ~789 rps (it pipelines a single cell ~3.8×). An echo
  path that never touches the DO costs ~172µs — wire+V8+docker floor
  — so ~96% of the turn is inside celld's DO/SQLite machinery, not
  transport. Koru's matching arm (`durable`, 013) sits at ~121µs.
  The named asymmetries: celld's ack is fsync-grade SQLite while
  `state.kv` is buffered `writeAll`+close — a new `durable+sync` arm
  (`std/fs:sync`, fs.sync.kz) spells that level and costs ~139µs/turn,
  and the baseline shows fsync ≈ ~7µs on this Mac's APFS, so celld's
  4.6ms is mostly its own machinery + virtio-fs, not the sync. Its
  durability oracle verified — n survives a container kill; ours
  proves process-death only. Also observed: sequential turns are
  exactly-once (101/101), but c8 runs each produced ~1 duplicate
  turn per connection — at-least-once visible on the request path,
  attribution between docker-proxy resets and celld's front retry
  unresolved. The honest comparison statement: same logical counter
  transition, different wire and durability levels, and both floors
  named — 121µs buffered / 139µs synced (in-process, no wire) vs
  ~4.6ms acknowledged (HTTP + V8 + SQLite + docker VM).
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
