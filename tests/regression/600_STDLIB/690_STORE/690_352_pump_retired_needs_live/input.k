// A `__pump_<name>_retired_<i>` unit on a join that answers no `! live` can
// never fire — an immortal participant never retires — so `run` refuses it
// rather than leaving a dead arm that looks armed.
import std/io
import std/pump
import lib/flicker

lib/flicker:light(a: 1, b: 2)

std/pump:create(main)
| drained |> std/io:print.ln("all retired")

tor __pump_main_retired_0 {}
__pump_main_retired_0() |> std/io:print.ln("a retired")

std/pump(main)
! step |> lib/flicker:a-step()

std/pump(main)
! step |> lib/flicker:b-step()
! live |> lib/flicker:b-live()

std/pump:run(main)
