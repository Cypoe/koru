# 800_007 — corral

**Pitch:** a stockyard indexed by `brand` — 256 head arrive in one herd,
every pen-2 animal is reshoed into pen 4 while a routed sweep walks it,
93 head are sold through swap-remove, and 240 more arrive against the
freed slots — where index membership must stay exact through every
verb that can corrupt it.

**Tier:** program-generation (runnable).

## What it is

`yard` is a 384-capacity store with `std/indexes:store(yard, brand)`.
`mir` shadows `brand` on every insert and rebrand — an unindexed column
carrying the same value — so `when x.brand == k` answers through the
index while `when x.mir == k` answers by full-sweep guard. `audit`
prints both per pen and folds squared disagreement into
`ledger.drift` — the pin is that it stays 0 after each phase. The token
threads `open! → driven! → culled!`.

## What it pressures

- **The index join itself.** 496 inserts through `std/indexes:store` —
  the primitive the price board measured as the worst emitted shape
  (~3.8ns/row, 7.3x the bare-array fill).
- **Writing the field a sweep routes on.** `reshoe` sweeps
  `when b.brand == 2` and writes `b.brand: 4` — bucket membership
  changes under the walk, and all 46 rows must land in pen 4.
- **Take under swap-remove.** `sell` takes every `mir == 4` row; each
  take slides the tail row into the freed slot, and that moved row's
  bucket entry must follow it (the `sold head` trace is deliberately
  non-sequential — the interleaved low/high order is the swap-remove
  tell).
- **`| full` and slot reuse.** Drive 2 asks for 240 with only 221 slots
  free — 19 meet `| full`, and the 221 that land reuse slots vacated by
  swap-remove, so handle→row and key→bucket agree again on recycled
  space.
- **Hot and cold buckets.** Uniform brands 0..4 (~50 members) plus a
  sparse brand 9 every 11th head (~24, then ~45 after refill).

## What it proved (and what it costs)

All three audits report drift 0 — the join is *correct* under churn.
The watch on `brand` counted 46 writes: exactly the reshoe volume, so
insert seeding does not announce through field watches — only `stored`
writes do. The challenge now stands as the correctness substrate the
`insert_idx` price-fix work must not break; when the join gets faster,
this is the program that has to stay right.

## Gaps / features targeted

- `when` routing on an indexed column vs a shadowed unindexed guard —
  routed/guarded agreement as the membership oracle.
- Indexed-field write inside a routed sweep (self-mutation under walk).
- Take payload carried through `| item` for the sale trace;
  `! removed` interceptor counting sales on the ledger.
- `| full` as a counted arm — capacity refusals are ledger data, not
  silent drops.
- Phantom phase token `i64<open!>`-family ordering the verbs.
