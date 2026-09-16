// THE TARGET SHAPE — SHAPE A: the store IS the participant.
//
// Same program as probes/r3/p3.k, written the way it wants to be written. The
// compiler's refusals against this file are the implementation list.
//
// What the shape says: a store whose rows carry an obligation already declares
// how they END (`! discharge`, store.kz:1137). It should equally declare how
// they ADVANCE. One more interceptor beside the four that exist
// (`discharge`/`inserted`/`removed`/`updated`, store.kz:1163).
//
// `! step` binds the row and calls the participant's step tor. The step's
// `| running` / `| complete` terminals are the STORE's to read, not the
// author's: `| complete` means this row is done, so the store takes it out and
// runs `! discharge` on it. That single rule deletes, from p3.k:
//
//   - `tor pass-fast` / `tor pass-slow`     (the per-store sweep wrapper)
//   - `| running |> _`                      (the stub you must write anyway)
//   - `std/store:new(ui) { retire: ... }`   (the retirement flag)
//   - `tor retire` + `std/store:take`       (the deferred-removal queue)
//
// 25 lines of scheduler → 0.
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

// SHAPE B — the schedule. `std/pump:create` declares it; `std/pump(main)`
// is the join — the participant's verbs arrive as `!` arms on the reference,
// join order is document order. `fast-step`/`fast-live` are the ordinary
// generated units the store's `! step` arm exposes — the pump composes
// names, never knowing a store answered.
std/pump:create(main)
| drained |> std/io:print.ln("all participants retired")

std/pump(main)
! step |> fast-step()
! live |> fast-live()

std/pump(main)
! step |> slow-step()
! live |> slow-live()

std/pump:run(main)
