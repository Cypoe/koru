// PROBE 3 — THE BASELINE. Two participants, one ordered pass, using only
// constructs that exist today. This is what downloads.k and d_turns.k arrive at
// by hand; every line below the divider is what `std/pump` would have to delete.
//
// Re-greened 2026-09-12 — the store surface moved under this probe since the
// 2026-08-01 spike, two ways:
//
//   - `std/store:sweep` is `std/store:query` (the read); the arm is `! query`.
//   - `take(store[0])` died with 690_242 — a row is addressed by HANDLE, so the
//     deferred retirement now carries the completed row's `[id]` through `ui`.
//
// `! discharge` is still REQUIRED here: `close` returns a value, so no exit
// from <live!> is unattended-callable and the column cannot auto-discharge.
// The arm is the teardown path — a row nobody retires still prints "retired".
//
// What survives intact — the hole this probe exists to show: `| complete`
// cannot take under a sweep, so retirement defers through a flag store, one
// slot per participant, and a completed row is still IN the store on the next
// pass and gets stepped again (fast's second `| complete` below).
import std/io
import std/store
import lib/srclib

// ---- the wire -------------------------------------------------------------
std/store:new(fast, capacity: 2) { *lib/srclib:Src<live!> }
! discharge s |> lib/srclib:close(s): id |> std/io:print.ln("retired {{ id:d }}")

std/store:new(slow, capacity: 2) { *lib/srclib:Src<live!> }
! discharge s |> lib/srclib:close(s): id |> std/io:print.ln("retired {{ id:d }}")

// ---- the scheduler, by hand -----------------------------------------------
// Two handle slots, exactly as d_turns.k:56 grew flags — one per participant,
// because a completed row cannot be taken from inside its own pass.
std/store:new(ui) { fast_h: -1[i64], slow_h: -1[i64] }

// One participant's pass. Written once per store, because a sweep names one
// store and nothing composes two.
tor pass-fast {}
pass-fast = std/store:query(fast)
! query { [row]s, [id]h } |> lib/srclib:step(s)
    ! moved i |> std/io:print.ln("fast moved {{ i:d }}")
    | running |> _
    | complete |> std/store:stored { ui.fast_h: h }

tor pass-slow {}
pass-slow = std/store:query(slow)
! query { [row]s, [id]h } |> lib/srclib:step(s)
    ! moved i |> std/io:print.ln("slow moved {{ i:d }}")
    | running |> _
    | complete |> std/store:stored { ui.slow_h: h }

// Ordering: `fast` before `slow` because these two lines are in that order.
// Nothing in the type system says so, and nothing would catch a swap.
tor pass {}
pass = pass-fast() |> pass-slow()

// One retire per participant, each guarded by its own slot — the deferred
// removal queue, spelled out. `-1` is the no-handle sentinel (690_070).
tor retire-fast {}
retire-fast = std/store:take(fast[ui.fast_h])
| item s |> lib/srclib:close(s): id |> std/io:print.ln("retired {{ id:d }}")
| empty |> _

tor retire-slow {}
retire-slow = std/store:take(slow[ui.slow_h])
| item s |> lib/srclib:close(s): id |> std/io:print.ln("retired {{ id:d }}")
| empty |> _

// ---- the program ----------------------------------------------------------
lib/srclib:open(id: 1, work: 2): a |> std/store:insert(fast) { a }
| row _ |> _
| full f |> lib/srclib:close(s: f): id |> std/io:print.ln("dropped {{ id:d }}")

lib/srclib:open(id: 2, work: 3): b |> std/store:insert(slow) { b }
| row _ |> _
| full f |> lib/srclib:close(s: f): id |> std/io:print.ln("dropped {{ id:d }}")

pass()
pass()
pass()
retire-fast()
retire-slow()
