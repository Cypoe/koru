// A pump participant that is NOT a store: lib/single holds module-level
// state (a counter) and answers the three verbs as plain tors. The join is
// identical in shape to a `! step` store's — the pump composes names.
import std/io
import std/pump
import lib/single

std/pump:create(main)
| drained |> std/io:print.ln("pump drained")

std/pump(main)
! step |> lib/single:step()
    ! stepped c |> std/io:print.ln("single stepped {{ c:d }}")
! live |> lib/single:live()
! wait i |> lib/single:wait(i)
    ! polled w |> std/io:print.ln("single interest {{ w:d }}")

std/pump:run(main)
