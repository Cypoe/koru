// PINS: first-class std/index — `std/index:store(players, key)` is a pure
// AST-data declaration (kernel:shape's `[norun]` pattern): it claims the
// site, never executes, and std/store's transforms discover it on the
// whole-program walk and emit what an indexed store needs — a key→handle
// map maintained inside insert/take/stored, and a `! first` whose `when`
// predicate on the indexed column routes to a map lookup instead of a sweep.
//
// Three oracles, one declaration:
//   1. `! first p when p.key == k` answers — the same spelling that scans
//      an unindexed store. The index is an organ decision, not a surface.
//   2. Swap-remove correctness: take the middle row and the row MOVED into
//      its slot must still resolve by key. An index kept from outside could
//      never see the move (no event fires for the displaced row); the fixup
//      has to live inside take's own emit.
//   3. Taken-key honesty: `! first` on the TAKEN row's key answers `| none`
//      — never a stale handle, never a generational trap.
// Plus the floor: a predicate on a NON-indexed column still scans and
// answers — declaring an index must not change what unindexed `when` means.

import std/store
import std/io

std/store:new(players, capacity: 8) { key: i64, val: i64 }
std/index:store(players, key)

std/store:insert(players) { key: 10, val: 100 }
| row a |> std/store:insert(players) { key: 20, val: 200 }
    | row b |> std/store:insert(players) { key: 30, val: 300 }
        |> std/store:take(players[a])
            | item _ |> std/io:print.ln("took")
            | empty |> std/io:print.ln("take-empty")

// the moved row still resolves by key
std/store:query(players)
    ! first p when p.key == 30 |> std/io:print.ln("moved {{ p.val:d }}")
    | none |> std/io:print.ln("moved LOST")

// the taken key is gone — none, never a stale deref
std/store:query(players)
    ! first p when p.key == 20 |> std/io:print.ln("taken {{ p.val:d }}")
    | none |> std/io:print.ln("taken none")

// a non-indexed predicate still scans
std/store:query(players)
    ! first p when p.val == 100 |> std/io:print.ln("scan {{ p.val:d }}")
    | none |> std/io:print.ln("scan lost")
