// PINS: a `for ! each |> insert` on an INDEXED store takes the bulk append
// lowering AND keeps the index — the batch emits the bucket join inside its
// fill loop, so bulk-inserted rows are visible to `! first` and `! query`
// routing exactly as per-row inserts are.

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
