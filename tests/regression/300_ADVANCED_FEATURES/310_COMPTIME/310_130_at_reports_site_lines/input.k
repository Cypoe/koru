// `koruc at` reports the line the user wrote, for every site class:
//   - a `|>`-chained site lands on the line its own `|>` stands on — the
//     flattened chain below stamps the `|> query` link at its line, not the
//     `| row` head's;
//   - nested arm sites (`! first`, `| none`) land on their `|`/`!` line;
//   - a flow's hash reports the flow head's own line.
// The bootstrap `import std/compiler` the frontend prepends is invisible:
// no reported line sits one past what the author wrote.
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
        |> std/store:query(players)
            ! first p when p.key == 30 |> std/io:print.ln("nested {{ p.val:d }}")
            | none |> std/io:print.ln("nested none")

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
    |> std/store:query(tree)
        ! first n when n.val == 20 |> std/io:print.ln("tree nested {{ n.val:d }}")
        | none |> std/io:print.ln("tree none")

std/store:query(tree)
    ! first n when n.val == 10 |> std/io:print.ln("root {{ n.val:d }}")
    | none |> std/io:print.ln("no root")
