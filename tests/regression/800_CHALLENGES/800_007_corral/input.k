// CHALLENGE 800_007 — "corral": index membership under churn.
//
// The primitive price board measured the index join as the worst
// emitted shape (~3.8ns/row vs the bare-array fill). This program makes
// the join the protagonist: a stockyard whose `brand` column carries an
// index, exercised through every verb that can corrupt membership —
// bulk arrival, reshoeing (writing the indexed field while a routed
// sweep walks it), sale by take (swap-remove must fix the moved row's
// bucket), and refills past the full mark (slot reuse).
//
// The pin is the audit: `mir` shadows `brand` on every write, so a
// guarded `when x.mir == k` sweep is ground truth and a routed
// `when x.brand == k` sweep is the index's answer. Stale buckets,
// missed re-bucketing, or a moved row lost to swap-remove all show as
// drift.
//
// Phase order is a type property: `open! → driven! → culled!`,
// closed by a consumer of i64<!culled>.

import std/io
import std/store
import std/indexes

// ── the yard token ───────────────────────────────────────────────

tor open-yard {} -> i64<open!>
open-yard -> 0

tor seal-driven { g: i64<!open> } -> i64<driven!>
seal-driven -> g

tor seal-culled { g: i64<!driven> } -> i64<culled!>
seal-culled -> g

tor close-yard { g: i64<!culled> } -> i64
close-yard -> g

// ── stores ───────────────────────────────────────────────────────

std/store:new(ledger) { rt: 0[i64], gd: 0[i64], drift: 0[i64], penned: 0[i64], turned: 0[i64], sold: 0[i64], moved: 0[i64] }

std/store:new(yard, capacity: 384) { brand: i32, mir: i32, head: i64 }
! removed _ |> std/store:stored { ledger.sold: ledger.sold + 1 }
std/indexes:store(yard, brand)

// Every write to the indexed field announces — insert seeds and
// reshoes both count.
std/store(yard)
! brand _ |> std/store:stored { ledger.moved: ledger.moved + 1 }

// ── phases ───────────────────────────────────────────────────────

// Bulk arrival: uniform pens 0..4 plus a sparse brand 9 every 11th
// head; `| full` counts the capacity wall, `| row` the pennings.
tor drive { n: i64, tag: i64 } {}
drive = for(0..@as(usize, @intCast(n)))
    ! each i |> std/store:insert(yard) {
        brand: if (@mod(@as(i64, @intCast(i)), 11) == 0) @as(i32, 9) else @as(i32, @intCast(@mod(@as(i64, @intCast(i)) + tag, 5))),
        mir: if (@mod(@as(i64, @intCast(i)), 11) == 0) @as(i32, 9) else @as(i32, @intCast(@mod(@as(i64, @intCast(i)) + tag, 5))),
        head: @as(i64, @intCast(i)) + tag * 100
    }
        | row _ |> std/store:stored { ledger.penned: ledger.penned + 1 }
        | full |> std/store:stored { ledger.turned: ledger.turned + 1 }

// Reshoe: a routed sweep that writes the field it routes on — every
// pen-2 head moves to pen-4 while the bucket walk is in flight.
tor reshoe {}
reshoe = std/store:query(yard)
! query b when b.brand == 2 |> std/store:stored { b.brand: 4, b.mir: 4 }

// Sale: guarded rule sweep on the shadow column, take under swap-
// remove — the row that slides into the freed slot must stay indexed.
tor sell {}
sell = std/store:rule(yard)
! row s when s.mir == 4 |> std/store:take(yard[s])
    | item i |> std/io:print.ln("sold head {{ i.head:d }} (brand {{ i.brand:d }})")

// ── the audit — routed index vs guarded truth, per pen ───────────

tor audit-reset {}
audit-reset = std/store:stored { ledger.rt: 0, ledger.gd: 0 }

tor audit-report { k: i64 } {}
audit-report = std/io:print.ln("pen {{ k:d }}: routed {{ ledger.rt:d }} vs guarded {{ ledger.gd:d }}")
    |> std/store:stored { ledger.drift: ledger.drift + (ledger.rt - ledger.gd) * (ledger.rt - ledger.gd) }

tor pen-routed-0 {}
pen-routed-0 = std/store:query(yard)
! query b when b.brand == 0 |> std/store:stored { ledger.rt: ledger.rt + 1 }

tor pen-guarded-0 {}
pen-guarded-0 = std/store:query(yard)
! query b when b.mir == 0 |> std/store:stored { ledger.gd: ledger.gd + 1 }

tor pen-routed-1 {}
pen-routed-1 = std/store:query(yard)
! query b when b.brand == 1 |> std/store:stored { ledger.rt: ledger.rt + 1 }

tor pen-guarded-1 {}
pen-guarded-1 = std/store:query(yard)
! query b when b.mir == 1 |> std/store:stored { ledger.gd: ledger.gd + 1 }

tor pen-routed-2 {}
pen-routed-2 = std/store:query(yard)
! query b when b.brand == 2 |> std/store:stored { ledger.rt: ledger.rt + 1 }

tor pen-guarded-2 {}
pen-guarded-2 = std/store:query(yard)
! query b when b.mir == 2 |> std/store:stored { ledger.gd: ledger.gd + 1 }

tor pen-routed-3 {}
pen-routed-3 = std/store:query(yard)
! query b when b.brand == 3 |> std/store:stored { ledger.rt: ledger.rt + 1 }

tor pen-guarded-3 {}
pen-guarded-3 = std/store:query(yard)
! query b when b.mir == 3 |> std/store:stored { ledger.gd: ledger.gd + 1 }

tor pen-routed-4 {}
pen-routed-4 = std/store:query(yard)
! query b when b.brand == 4 |> std/store:stored { ledger.rt: ledger.rt + 1 }

tor pen-guarded-4 {}
pen-guarded-4 = std/store:query(yard)
! query b when b.mir == 4 |> std/store:stored { ledger.gd: ledger.gd + 1 }

tor pen-routed-9 {}
pen-routed-9 = std/store:query(yard)
! query b when b.brand == 9 |> std/store:stored { ledger.rt: ledger.rt + 1 }

tor pen-guarded-9 {}
pen-guarded-9 = std/store:query(yard)
! query b when b.mir == 9 |> std/store:stored { ledger.gd: ledger.gd + 1 }

tor audit {}
audit = std/io:print.ln("-- audit --")
    |> audit-reset() |> pen-routed-0() |> pen-guarded-0() |> audit-report(k: 0)
    |> audit-reset() |> pen-routed-1() |> pen-guarded-1() |> audit-report(k: 1)
    |> audit-reset() |> pen-routed-2() |> pen-guarded-2() |> audit-report(k: 2)
    |> audit-reset() |> pen-routed-3() |> pen-guarded-3() |> audit-report(k: 3)
    |> audit-reset() |> pen-routed-4() |> pen-guarded-4() |> audit-report(k: 4)
    |> audit-reset() |> pen-routed-9() |> pen-guarded-9() |> audit-report(k: 9)

// ── the run ──────────────────────────────────────────────────────
//
// drive 256 into capacity 384, audit, reshoe pen 2 into pen 4
// mid-walk, audit, sell every pen-4 row (swap-remove churns buckets),
// then drive 240 — the freed slots refill and the rest meet `| full`
// — and audit.

open-yard(): g
|> drive(n: 256, tag: 0)
    |> audit()
    |> reshoe()
    |> audit()
    |> sell()
    |> seal-driven(g): g1
    |> drive(n: 240, tag: 2)
    |> audit()
    |> seal-culled(g: g1): g2
    |> close-yard(g: g2): r
    |> std/io:print.ln("corral closed: {{ ledger.penned:d }} penned, {{ ledger.turned:d }} turned away, {{ ledger.sold:d }} sold, {{ ledger.moved:d }} brand-writes, drift {{ ledger.drift:d }} (yard {{ r:d }})")
