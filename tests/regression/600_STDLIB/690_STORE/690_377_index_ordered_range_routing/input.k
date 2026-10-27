// ASPIRATION — TODO idea pin. `std/indexes:ordered(<store>, <col>)`
// (spelling PROVISIONAL) declares an ORDERED index occupying the same
// one-declaration slot as `std/indexes:store` (690_328's wall) — a key
// directory whose distinct keys are sorted, each naming its member
// handles in join order.
//
// What it buys, pinned here as observable semantics:
//   1. A RANGE guard (`<`, `<=`, `>`, `>=`) on the ordered column routes
//      and visits in ASCENDING KEY ORDER — join order inside each key's
//      bucket. Dense order is deliberately scrambled below so a sweep
//      cannot satisfy this output.
//   2. `! first` under a routed range answers the first member of THE
//      WALK — lowest matching key's first member — not the lowest dense
//      match. Same contract the equality route already carries (the
//      visit order is the index's, not the store's).
//   3. `==` still routes through the same directory — the ordered index
//      is a superset of the equality one, never a second structure.
//   4. The maintenance contract is unchanged: a `stored` write to the
//      ordered column moves membership eagerly (joining the new bucket
//      at the end); `take` inside a routed range walk leaves a dead
//      member every reader skips (690_341's survival walk, held at
//      directory granularity).
//   5. Floor: a guard on a NON-indexed column still sweeps in dense
//      order.
//
// Honoring means the `guardKey`/`guardRoute` boundary in store.index.kz
// gains range arms over an ordered directory — route-vs-scan is already
// the architecture's decision point, so this is a widening, not a new
// mechanism. At store scale the honest structure is a sorted key array
// plus binary search over per-key member lists; a B-tree earns the slot
// only if the distinct-key domain ever outgrows a flat directory.
//
// THE CREDITOR — none yet, and that is the point: today a `>=` guard
// sweeps and answers correctly in dense order, so nothing is broken.
// This pin holds the semantics so the first range-predicate workload has
// a test-shaped door to walk through instead of an unexamined sweep.

import std/store
import std/indexes
import std/io

std/store:new(players, capacity: 8) { key: i64, val: i64 }
std/indexes:ordered(players, key)

// Joined interleaved — dense order is 30, 20, 10, 31, 11; key order is
// 1:(10,11), 2:(20), 3:(30,31). Any answer that follows dense order is
// a sweep wearing routed clothing.
std/store:insert(players) { key: 3, val: 30 }
std/store:insert(players) { key: 2, val: 20 }
std/store:insert(players) { key: 1, val: 10 }
std/store:insert(players) { key: 3, val: 31 }
std/store:insert(players) { key: 1, val: 11 }

// 1. range guard visits ascending by key, join order within a bucket
std/store:query(players)
! query p when p.key >= 2 |> std/io:print.ln("ge2 {{ p.val:d }}")

// 2. `! first` answers the walk's first member — key 2's bucket head,
//    NOT the lowest dense match (30 at slot 0)
std/store:query(players)
! first p when p.key >= 2 |> std/io:print.ln("first {{ p.val:d }}")
| none |> std/io:print.ln("first none")

// 3. `==` routes through the same directory — join order in the bucket
std/store:query(players)
! query p when p.key == 3 |> std/io:print.ln("eq3 {{ p.val:d }}")

// 4. upper bounds visit ascending from the lowest key
std/store:query(players)
! query p when p.key <= 2 |> std/io:print.ln("le2 {{ p.val:d }}")

// 5. a write to the ordered column moves membership eagerly — the val-31
//    row leaves key 3's bucket and joins key 1's AT THE END
std/store:query(players)
! first p when p.val == 31 |> std/store:stored { p.key: 1 }
| none |> std/io:print.ln("no val-31")

std/store:query(players)
! query p when p.key >= 2 |> std/io:print.ln("ge2' {{ p.val:d }}")

std/store:query(players)
! query p when p.key == 1 |> std/io:print.ln("eq1 {{ p.val:d }}")

// 6. floor: a guard on the non-indexed column still sweeps, dense order
std/store:query(players)
! query p when p.val >= 20 |> std/io:print.ln("scan {{ p.val:d }}")

// 7. take inside a routed range walk — each taken row's member entry
//    goes dead; every remaining member is still visited
std/store:query(players)
! query p when p.key >= 2 |> std/store:take(players[p])
    | item i |> std/io:print.ln("took {{ i.val:d }}")

std/store:query(players)
! first p when p.key >= 2 |> std/io:print.ln("ge2 {{ p.val:d }}")
| none |> std/io:print.ln("ge2 none")

std/store:query(players)
! first p when p.key == 1 |> std/io:print.ln("eq1' {{ p.val:d }}")
| none |> std/io:print.ln("eq1' none")
