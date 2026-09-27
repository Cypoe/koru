// `__pump_<name>_retired_<i>` — the per-participant retirement unit a
// capture-aware participant emits — fires exactly once, on the first pass
// whose `live` answers 0, ahead of `| drained`. `a` burns out after two
// steps while `b` keeps the pump alive past the crossing: a refire per idle
// pass would print the line three times — the one-shot flag is the pin.
import std/io
import std/pump
import lib/flicker

lib/flicker:light(a: 2, b: 4)

std/pump:create(main)
| drained |> std/io:print.ln("all retired")

// Hand-declared here; a capture transform emits this pair itself — the unit
// name is the convention `run` enumerates.
tor __pump_main_retired_0 {}
__pump_main_retired_0() |> std/io:print.ln("a retired")

std/pump(main)
! step |> lib/flicker:a-step()
! live |> lib/flicker:a-live()

std/pump(main)
! step |> lib/flicker:b-step()
! live |> lib/flicker:b-live()

std/pump:run(main)
