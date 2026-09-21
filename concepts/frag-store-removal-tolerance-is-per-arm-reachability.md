---
type: belief
id: frag-store-removal-tolerance-is-per-arm-reachability
provenance: 690_301/690_300 pair — the program-wide take-scan pessimised every query; per-arm reachability landed 2026-09-11 and the dying pin died on schedule
ts: 2026-09-11
---

# Removal tolerance is a property of the arm, not the program (belief)

A store query emits the removal-tolerant `while` only because a `take` can move
the cursor's row mid-sweep. Whether it CAN is a reachability question about the
arm's own tree — takes invoked by the arm's chain plus takes reachable through
the `impl_of` subflows it calls — not a question about the program at all. The
earlier implementation scanned the whole program for any `std/store:take` and
pessimised every query on the result: a take against a different store, an
unrelated word containing "take", anything. Measured cost of that over-approx:
roughly 6.1x on the sweep that did not need the tolerant loop (the dense
`for (0..len)` cursor is the vectorizable shape — the `for`-not-`while` rule
applied to a decision, not just a spelling).

The conservative instinct that produced the program-wide scan is worth naming:
absence-of-removal is the dangerous direction to get wrong (a missed take under
a dense cursor is silent corruption), so "any take anywhere ⇒ slow loop" felt
safe. But safety was already available per-arm — the arm is the unit that
executes, so reachability from it is the exact boundary of what can move its
cursor. The two pins were written as a pair on purpose: `690_300` declared its
own death in its header ("dies when per-arm analysis lands; `690_301` is the
replacement") and was deleted the day it fired — a pin designed to be retired
by the fix, not to drift red beside it.

Now pinned: `690_301` (unrelated take ⇒ `for`), `690_031` (in-arm take ⇒
`while`). Still conservative in the safe direction: an arm that calls a flow
whose body takes counts, and already-lowered `__store_take_<store>` names
count, so a take the scan cannot see through is treated as present rather than
missed.

**Evolved 2026-10 — the arm-level lattice has a third lowering.** A `! row`
body that is *only* `take(s[e])` with the `| item` payload discarded is a
drain: every visited row dies, so the payload materialisation and the
swap-remove column traffic exist for nobody. The invoked sweep lowers to the
bookkeeping alone — and the lesson is that **removal order is observable**.
Freelist push order determines which handles a refill mints, and handles are
plain `i64`s a program can print and compare, so the bulk form must reproduce
sequential take's push order, not just its final count. That order turns out
to be a read-only traversal — `row_hslot[0]`, then `row_hslot[n-1]` down to
`row_hslot[1]` — because the tolerant loop always re-takes index 0 and
swap-remove keeps dropping the last row into the hole. `clear`'s canonical
reset was the wrong lowering for the same reason. Decline conditions stay
conservative: guard, `[id]`, owned columns, `! removed` arms, index columns,
preorder, any body shape the recognizer cannot name. Pinned `690_336`
(shape + decline) — measured 1582µs → ~1.0ms on the 100k×100 despawn board
scenario; the residual over a bare `world.deinit` anchor is the bookkeeping
itself, which is semantic, not emission.

The same work surfaced the complementary invariant on the resolve side: a
dense index `row_of` returns must be `< len`, and a taken slot's
`hslot_row` is tombstoned — because a reactive rule can consume a row inside
`insert`, before the insert's own `| row h` handle is minted, producing a
live-generation handle to a dead slot. Without the bounds check that handle
resolved to dense row 0 of an emptied store and `take` underflowed `len`.
Pinned `690_337`.
