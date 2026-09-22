// PINS: a `for ! each |> insert` on an INDEXED store does NOT take the bulk
// append lowering — the `bulkable` gate requires `declsOf == 0` because the
// batch writes columns raw and would leave every row it added invisible to
// the index's buckets. The site stays per-row and membership is maintained.

import std/store
import std/indexes
import std/io
import std/control

std/store:new(players, capacity: 8) { key: i64, val: i64 }
std/indexes:store(players, key)
std/store:new(acc) { n: 0[i64] }
std/store:new(out) { v: 0[i64] }

std/store:watch(out)
! v x |> std/io:print.ln("{{ x:d }}")

for(0..4)
    ! each i |> std/store:insert(players) { key: 2, val: @as(i64, @intCast(i)) }

std/store:query(players)
    ! first p when p.key == 2 |> std/io:print.ln("first {{ p.val:d }}")
    | none |> std/io:print.ln("lost")

std/store:query(players)
! query p when p.key == 2 |> std/store:stored { acc.n: acc.n + 1 }

std/store:stored { out.v: acc.n }
