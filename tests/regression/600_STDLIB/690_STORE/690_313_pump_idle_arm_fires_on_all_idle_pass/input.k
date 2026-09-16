// `! idle` on `pump:run` — the pump's own effect, fired when a whole pass
// stepped every live row and nobody progressed (no row answered `| running`
// or `| complete` — the only two words the pump reads; the sources' `| quiet`
// here is an author-named no-progress verdict like any other). The arm runs
// inside the loop — sleep, kevent, a tick — and the next pass begins when it
// returns. This is the composition seam for blocking-shaped participants.
//
// The participants are real fds (socketpairs): `tick` delivers a byte every
// third step and answers `quiet` between; `tty`/`sock` poll before reading —
// the orisha shape. `want: 2` retires both sources on the second delivery;
// `tick` retires after seven steps. The four "pump idle" lines pin the passes
// where every live participant made no progress — including the two passes
// where only the unfinished tick was still being stepped.
import std/io
import std/store
import std/pump
import std/time
import lib/srcchan

std/store:new(tick, capacity: 2) { *lib/srcchan:Tick<live!> }
! step t |> lib/srcchan:step-tick(t)
    ! ticked i |> std/io:print.ln("tick {{ i:d }}")
! discharge t |> lib/srcchan:close-tick(t): id |> std/io:print.ln("tick retired {{ id:d }}")

std/store:new(tty, capacity: 2) { *lib/srcchan:Src<live!> }
! step s |> lib/srcchan:step-src(s)
    ! moved i |> std/io:print.ln("tty read {{ i:d }}")
    ! waited i |> std/io:print.ln("tty idle {{ i:d }}")
! discharge s |> lib/srcchan:close-src(s): id |> std/io:print.ln("tty retired {{ id:d }}")

std/store:new(sock, capacity: 2) { *lib/srcchan:Src<live!> }
! step s |> lib/srcchan:step-src(s)
    ! moved i |> std/io:print.ln("sock read {{ i:d }}")
    ! waited i |> std/io:print.ln("sock idle {{ i:d }}")
! discharge s |> lib/srcchan:close-src(s): id |> std/io:print.ln("sock retired {{ id:d }}")

lib/srcchan:open-src(id: 1, want: 2): a
|> lib/srcchan:open-src(id: 2, want: 2): b
|> lib/srcchan:open-tick(id: 0, a, b, ticks: 7): t
|> std/store:insert(tick) { t }
| row _ |> std/store:insert(tty) { a }
    | row _ |> std/store:insert(sock) { b }
        | row _ |> _
        | full f |> lib/srcchan:close-src(s: f): id |> std/io:print.ln("dropped sock {{ id:d }}")
    | full f |> lib/srcchan:close-src(s: f): id |> std/io:print.ln("dropped tty {{ id:d }}")
        |> lib/srcchan:close-src(s: b): id2 |> std/io:print.ln("dropped sock {{ id2:d }}")
| full f |> lib/srcchan:close-tick(t: f): id |> std/io:print.ln("dropped tick {{ id:d }}")
    |> lib/srcchan:close-src(s: a): id2 |> std/io:print.ln("dropped tty {{ id2:d }}")
    |> lib/srcchan:close-src(s: b): id3 |> std/io:print.ln("dropped sock {{ id3:d }}")

std/pump:create(main)
| drained |> std/io:print.ln("all participants retired")

std/pump(main)
! step |> tick-step()
! live |> tick-live()

std/pump(main)
! step |> tty-step()
! live |> tty-live()

std/pump(main)
! step |> sock-step()
! live |> sock-live()

std/pump:run(main)
! idle |> std/io:print.ln("pump idle — nothing ready anywhere") |> std/time:sleep-ms(ms: 2)
