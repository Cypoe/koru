// The pump slice: `! step` on a one-owned-column store + `std/pump`.
//
// `! step s |> lib/srclib:step(s)` declares how a row ADVANCES; the step tor's
// `|` verdicts are the store's to read — `| complete` retires the row in place
// (the `! discharge` arm runs it out), every other verdict keeps it. The
// generated pass steps each row once and never steps a retired row — the
// hand-written version of this (the sweep + handle-slot + deferred `take`
// scheduler of the r3 probe) is the code this slice replaces.
//
// `std/pump:create(name)` declares the pump; `std/pump(name)` is the join
// form — a participant attaches its verbs (`! step`/`! live`) as arms on the
// reference, and joins land in document order = pass order. The store's
// `! step` arm exposes those verbs as the ordinary units `<store>-step` /
// `<store>-live`; the pump composes names, not stores.
// `std/pump:run(name)` loops passes until every participant's `live` answers
// 0, then fires the declaration's `| drained` arm.
//
// `close -> i64` is not unattended-callable, so `! discharge` is required and
// IS the retirement path — the pinned output shows it running from inside the
// pass, not at teardown.
import std/io
import std/store
import std/pump
import lib/srclib

std/store:new(fast, capacity: 2) { *lib/srclib:Src<live!> }
! step s |> lib/srclib:step(s)
    ! moved i |> std/io:print.ln("fast moved {{ i:d }}")
! discharge s |> lib/srclib:close(s): id |> std/io:print.ln("retired {{ id:d }}")

std/store:new(slow, capacity: 2) { *lib/srclib:Src<live!> }
! step s |> lib/srclib:step(s)
    ! moved i |> std/io:print.ln("slow moved {{ i:d }}")
! discharge s |> lib/srclib:close(s): id |> std/io:print.ln("retired {{ id:d }}")

lib/srclib:open(id: 1, work: 2): a |> std/store:insert(fast) { a }
| row _ |> _
| full f |> lib/srclib:close(s: f): id |> std/io:print.ln("dropped {{ id:d }}")

lib/srclib:open(id: 2, work: 3): b |> std/store:insert(slow) { b }
| row _ |> _
| full f |> lib/srclib:close(s: f): id |> std/io:print.ln("dropped {{ id:d }}")

std/pump:create(main)
| drained |> std/io:print.ln("all participants retired")

std/pump(main)
! step |> fast-step()
! live |> fast-live()

std/pump(main)
! step |> slow-step()
! live |> slow-live()

std/pump:run(main)
