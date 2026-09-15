// `! first` under a tor's inputs — the find-or-join shape. The `when` guard
// reads `k` site-locally; the sweep body writes the matched row through
// `stored` and reads `k` as a threaded capture; the `| none` body reads `k`
// the same way. One arm pair replaces the sweep-with-sentinel a "find one
// row" site needed before.

import std/store
import std/io

std/store:new(items, capacity: 16) { k: i32, v: i32 }

for(0..3)
! each i |> std/store:insert(items) { k: @as(i32, @intCast(i)), v: 0 }

tor touch { k: i32 }

touch = std/store:query(items)
    ! first e when e.k == k |> std/store:stored { e.v: k * 10 }
    | none |> std/io:print.ln("missing {{ k:d }}")

touch(k: 0)
touch(k: 1)
touch(k: 9)

std/store:query(items)
    ! query e |> std/io:print.ln("item {{ e.k:d }} = {{ e.v:d }}")
