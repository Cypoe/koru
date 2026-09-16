// Test: `koruc explain` on a participant store — `std/store:new` with
// `! step`/`! wait` exposes `<s>-step`/`<s>-live`/`<s>-wait`, which the
// pump joins by name. The two explainers corroborate across the
// generated-name channel: store reports "pump participant — exposes
// tasks-step …" and pump reports each callee as "synthesized by
// std/store:new(tasks)" — pre-transform, those units don't exist yet,
// so the report names their generator rather than demanding a decl.
// post.sh drives the text rows and the typed json catalog.
import std/io
import std/store
import std/pump
import std/explain
import lib/tasklib

std/store:new(tasks, capacity: 4) { *lib/tasklib:Task<live!> }
! step s |> lib/tasklib:work(s)
! discharge s |> lib/tasklib:done(s)
! wait t |> lib/tasklib:poll(t)

std/pump:create(main)
| drained |> std/io:print.ln("drained")

std/pump(main)
! step |> tasks-step()
! live |> tasks-live()
! wait i |> tasks-wait(i)

std/pump:run(main)
