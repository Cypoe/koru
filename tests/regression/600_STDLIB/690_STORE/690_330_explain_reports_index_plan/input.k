// Test: `koruc explain` reports index routing — the SQL-EXPLAIN namesake
// rung. A `std/indexes:store(players, key)` declaration shows as an
// `index = key` row witnessed by the declaration's own site hash, and each
// query site gets the plan the transform's own fold decides: a `! first`
// whose `when` names the indexed column is an `index lookup`, a `! query`
// is a `sweep`, and a `! first` on a non-indexed column is a `sweep` that
// stops at first match. A `[tree]` store plans its queries like any other
// — the fold reports the transform's own column surface, so a guard on a
// real column plans a sweep and a guard on the invisible `parent` would
// refuse with the transform's own words, never a guessed plan. The program
// itself still runs — the plans it reports are the routes it executes.
import std/io
import std/store
import std/indexes
import std/explain

std/store:new(players, capacity: 8) { key: i64, val: i64 }
std/indexes:store(players, key)

std/store:insert(players) { key: 10, val: 100 }
| row a |> std/store:insert(players) { key: 20, val: 200 }
    | row b |> std/store:insert(players) { key: 30, val: 300 }
        |> std/io:print.ln("seeded")

// routed: the guard's equality is on the indexed column
std/store:query(players)
    ! first p when p.key == 30 |> std/io:print.ln("first {{ p.val:d }}")
    | none |> std/io:print.ln("first none")

// sweep: visits every row
std/store:query(players)
    ! query q |> std/io:print.ln("row {{ q.key:d }}")

// scan: the predicate names a non-indexed column — same `! first`
// spelling, no index to route through
std/store:query(players)
    ! first p when p.val == 100 |> std/io:print.ln("scan {{ p.val:d }}")
    | none |> std/io:print.ln("scan none")

// a [tree] store: its `parent` self-FK is synthesized by the annotation
// and invisible to the query surface — plans for it read the same column
// list the transform does
[tree]std/store:new(tree, capacity: 4) { val: i64 }

std/store:insert(tree) { val: 10 }
| row r |> std/store:insert(tree) { val: 20 }
    |> std/io:print.ln("tree seeded")

std/store:query(tree)
    ! first n when n.val == 10 |> std/io:print.ln("root {{ n.val:d }}")
    | none |> std/io:print.ln("no root")
