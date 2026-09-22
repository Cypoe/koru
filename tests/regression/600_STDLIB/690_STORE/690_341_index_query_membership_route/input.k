// PINS: `! query <row> when <row>.<icol> == <k>` on an `std/indexes`-declared
// store routes to the key's membership bucket instead of sweeping — the same
// declaration `! first` consumes, widened to a key→ordered-member map.
// Three oracles, one mechanism:
//   1. Membership: the routed query visits exactly the rows carrying the
//      key, in join order — the bucket's order, which coincides with the
//      sweep's until a take reshuffles dense slots.
//   2. A `stored` write to the indexed column MOVES membership eagerly:
//      the row leaves the old bucket and joins the new one at the end —
//      a write that moves membership is a join for ordering purposes.
//   3. A take inside a routed query is safe: the taken row's handle stays
//      a dead member the row-resolve skips — the sweep's re-check
//      contract (690_031) carried at bucket granularity.
// Plus the floor: a `when` on a NON-indexed column still sweeps, and
// `! first` still answers the lowest dense live member (690_327's parity).

import std/store
import std/indexes
import std/io

std/store:new(players, capacity: 8) { key: i64, val: i64 }
std/indexes:store(players, key)

std/store:insert(players) { key: 1, val: 10 }
std/store:insert(players) { key: 2, val: 20 }
std/store:insert(players) { key: 1, val: 11 }
std/store:insert(players) { key: 1, val: 12 }
std/store:insert(players) { key: 2, val: 21 }

// 1. routed membership, join order
std/store:query(players)
! query p when p.key == 1 |> std/io:print.ln("one {{ p.val:d }}")

// 2. the val==11 row moves to key 2 — membership follows the write
std/store:query(players)
! first p when p.val == 11 |> std/store:stored { p.key: 2 }

std/store:query(players)
! query p when p.key == 1 |> std/io:print.ln("one' {{ p.val:d }}")

std/store:query(players)
! query p when p.key == 2 |> std/io:print.ln("two {{ p.val:d }}")

// 3. take every key-2 member inside the routed walk — all three must be
//    visited even though each take is mid-iteration
std/store:query(players)
! query p when p.key == 2 |> std/store:take(players[p])
    | item i |> std/io:print.ln("took {{ i.val:d }}")

// the taken rows are gone — the bucket answers honestly through dead members
std/store:query(players)
    ! first p when p.key == 2 |> std/io:print.ln("key2 {{ p.val:d }}")
    | none |> std/io:print.ln("key2 none")

// the untouched bucket is still whole
std/store:query(players)
! query p when p.key == 1 |> std/io:print.ln("last {{ p.val:d }}")

// floor: a non-indexed predicate still scans
std/store:query(players)
! query p when p.val == 10 |> std/io:print.ln("scan {{ p.val:d }}")

// 4. a routed query whose body writes the INDEXED column takes the
//    survival walk — each visited member leaves the bucket mid-iteration
//    and hands its slot to the next unvisited member, which the walk must
//    still examine. Both key-1 rows must move, exactly once each.
std/store:query(players)
! query p when p.key == 1 |> std/store:stored { p.key: 9 }

std/store:query(players)
! query p when p.key == 9 |> std/io:print.ln("nine {{ p.val:d }}")
