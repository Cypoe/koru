// A join's `! step` must name a declared `-> i32` unit — the pump composes
// compile-time-known verbs. A store that never declared `! step` exposes no
// `<store>-step` unit, so joining on one refuses: the pump would have
// nothing to call on its pass.
import std/io
import std/store
import std/pump

std/store:new(pool, capacity: 4) { hp: i64 }

std/pump:create(main)
| drained |> std/io:print.ln("done")

std/pump(main)
! step |> pool-step()
! live |> pool-live()

std/pump:run(main)
