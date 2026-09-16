// vaxis as a pump participant. `lib/vloop` is a singleton: module state, a
// pipe fd, a tick deadline — the exact shape of vaxis's run loop (tryEvent
// drain + should_quit + next_tick), minus the loop itself, which the pump
// now supplies. The join is byte-identical in shape to a `! step` store's.
import std/io
import std/pump
import lib/vloop

lib/vloop:open(): _

std/pump:create(main)
| drained |> std/io:print.ln("vloop drained")

std/pump(main)
! step |> lib/vloop:step()
    ! byte b |> std/io:print.ln("byte {{ b:d }}")
    ! tick ms |> std/io:print.ln("tick")
! live |> lib/vloop:live()
! wait i |> lib/vloop:wait(i)

std/pump:run(main)
