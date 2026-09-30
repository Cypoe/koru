// A record-field obligation issued and discharged INSIDE a `std/store:query`
// arm. The arm is a transplanted sweep body (`__store_sweepbody_`, 690_252);
// `make` returns `{ h: *Handle<owned!>, n: i64 }` (330_096's field shape) and
// the arm pays `r.h` off per row with `lib/res:dispose(r.h)` — issue-local,
// discharge-local, inside an iterated body. Locks the composition: the sweep
// transplant keeps per-field obligation tracking both ways (the drop sibling
// raises KORU030; this discharge credits).
import std/io
import std/store
import app/lib/res

std/store:new(items, capacity: 4) { v: i64 }
std/store:insert(items) { v: 7 }
| row _ |> _
std/store:insert(items) { v: 8 }
| row _ |> _

std/store:query(items)
! query e |> app/lib/res:make(id: e.v): r |> app/lib/res:dispose(r.h) |> std/io:print.ln("n={{ r.n:d }}")
