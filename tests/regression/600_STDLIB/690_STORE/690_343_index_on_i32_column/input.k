// PINS: `std/indexes:store(s, col)` on a non-i64 column — the bucket map's
// key type follows the column's declared width, not a hardcoded i64. The
// benchmark's `act: i32` index is the first non-i64 key in the corpus, so
// this pins that routing, an eager membership move on an i32 write, a
// dead member after take, and a negative key all behave as on i64.
// The emit oracle (post.sh) checks the map key type is the column's own.

import std/store
import std/indexes
import std/io

std/store:new(tags, capacity: 8) { grp: i32, val: i32 }
std/indexes:store(tags, grp)

std/store:insert(tags) { grp: 1, val: 10 }
std/store:insert(tags) { grp: 2, val: 20 }
std/store:insert(tags) { grp: -5, val: 50 }
std/store:insert(tags) { grp: 1, val: 11 }
std/store:insert(tags) { grp: 3, val: 30 }

std/store:query(tags)
! query t when t.grp == 1 |> std/io:print.ln("one {{ t.val:d }}")

// a signed key routes the same way
std/store:query(tags)
! query t when t.grp == -5 |> std/io:print.ln("neg {{ t.val:d }}")

// a stored write to the i32 key moves membership eagerly
std/store:query(tags)
! first t when t.val == 30 |> std/store:stored { t.grp: 1 }

std/store:query(tags)
! query t when t.grp == 1 |> std/io:print.ln("one' {{ t.val:d }}")

// take inside the routed walk leaves dead members the resolve skips
std/store:query(tags)
! query t when t.grp == 1 |> std/store:take(tags[t])
    | item i |> std/io:print.ln("took {{ i.val:d }}")

std/store:query(tags)
    ! first t when t.grp == 1 |> std/io:print.ln("still {{ t.val:d }}")
    | none |> std/io:print.ln("all gone")

// the untouched buckets are still whole
std/store:query(tags)
! query t when t.grp == -5 |> std/io:print.ln("neg' {{ t.val:d }}")
