// PINS: a `for ! each |> insert` on an INDEXED store takes the bulk append
// lowering AND keeps the index — the batch emits the bucket join inside its
// fill loop, so bulk-inserted rows are visible to `! first` and `! query`
// routing exactly as per-row inserts are. The `tags` half pins the
// multi-key shape: a boundary every row through three keys, then a second
// batch that must keep appending to the SAME buckets — the bucket memo and
// the just-left cache both have to stay honest.

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

std/store:new(tags, capacity: 16) { grp: i32, val: i32 }
std/indexes:store(tags, grp)

// three keys cycling — every row is a boundary, and keys 1/2 arrive fresh
// mid-batch (the map's rehash path must not hand back a moved bucket)
for(0..10)
    ! each i |> std/store:insert(tags) { grp: @as(i32, @intCast(i % 3)), val: @as(i32, @intCast(i)) }

// two keys alternating into the SAME store — appends to live buckets
for(10..16)
    ! each i |> std/store:insert(tags) { grp: @as(i32, @intCast(i % 2)), val: @as(i32, @intCast(i)) }

std/store:query(tags)
! query t when t.grp == 0 |> std/io:print.ln("g0 {{ t.val:d }}")

std/store:query(tags)
! query t when t.grp == 1 |> std/io:print.ln("g1 {{ t.val:d }}")

std/store:query(tags)
! query t when t.grp == 2 |> std/io:print.ln("g2 {{ t.val:d }}")
