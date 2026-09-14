---
type: belief
id: frag-spawning-n-entities-is-a-counter-not-a-loop
provenance: asteroids wave system (koru-libs games/asteroids, 2026-09-14) —
  the bradcypert/asteroids-demos contract needs "spawn 3+wave rocks" with a
  runtime count; the first sketch reached for a dynamic-bound loop inside a
  sweep, and the shipped shape is a pending counter + one insert per tick
ts: 2026-09-14
---

# Spawning N entities is a pending counter and a per-tick arm, not a loop over N (belief)

When a world rule must insert a runtime number of rows — wave N wants 3+N
rocks — the store grammar's native shape is the one it already uses for
every other "happens over time" quantity (`cd`, `inv`, `t`): a field on the
bookkeeping row, a guard arm, a decrement.

- An arm stores `pending` on the game row: `wave-check` fires
  `when rocks <= 0 and pending <= 0` and stores `pending: wave + 4`.
- A second arm spends it: `spawn-tick` fires `when pending > 0`, does its
  draws, inserts ONE row, and stores `pending - 1`.
- The census that drives the trigger is the same pattern again — every
  insert and take funnels through `bump-rocks`, so `rocks` is a live count
  and no rule ever needs NOT EXISTS.

Three properties fall out for free: determinism (each spawn is one query arm
doing its LCG draws in sequence — the receipts pin exact positions), atomic
visibility (the field materializes over ~70ms at 60Hz, which is a feature —
rocks fade in, never pop), and no new language surface (every shape used —
guarded arm, insert inside a sweep, stored on the swept row — was already
proven in the same file).

This does NOT close the question of `for(0..runtime_bound)` inside a sweep
continuation — that stays unmeasured, and a fixed trip count over a bound
value is a different problem (iteration over known structure, not creation
of new rows). The ruling is narrower: *entity creation with a runtime count
is already expressible*; reach for the counter before reaching for a loop.

## Open

- `for(0..bound)` over a store-row value inside a sweep arm — unmeasured.
  If a future instrument needs per-frame burst spawning (a blast of 40
  particles in one tick), that is where the loop question reopens — and the
  per-tick counter may need a batch arm (spawn k per tick) as its real
  answer.
