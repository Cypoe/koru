// MIRROR: a `std/pump` join + run whose participant lives in an imported
// module. `app/lib` holds the singleton's state and answers the three verbs;
// the entry composes them by qualified name — the pump composes names, so
// module qualification is the only thing this test exists to prove.
import std/io
import std/pump
import app/lib

std/pump:create(main)
| drained |> std/io:print.ln("pump drained")

std/pump(main)
! step |> app/lib:step()
    ! stepped c |> std/io:print.ln("single stepped {{ c:d }}")
! live |> app/lib:live()
! wait i |> app/lib:wait(i)

std/pump:run(main)
