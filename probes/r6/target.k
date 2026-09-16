// PROBE 6 — THE COMPOSITION SEAM, CLOSED. Two blocking-shaped event sources
// and a producer, composed by std/pump — one thread, one kernel wait.
//
//   tick — stands in for the OS: each step writes a byte to the sources'
//          pipes every THIRD step and answers `| quiet` between; its `! wait`
//          interest is a 5ms re-poll duration (it has no fd).
//   tty  — a socketpair read end; step polls, reads when ready, `| complete`
//          after `want` bytes; its `! wait` interest is the read fd.
//          (vaxis: tty input is an fd.)
//   sock — same, different pipe. (orisha: a connection socket.)
//
// An unarmed `! idle` runs the pump's union wait: each all-idle pass collects
// `{ fd, wait_ns }` per live row and blocks once — poll over both socketpair
// fds capped by the tick's 5ms. The "interest fd" lines make the collection
// visible; the sources' reads arrive exactly when the writes land.
import std/io
import std/store
import std/pump
import std/time
import lib/srcchan

std/store:new(tick, capacity: 2) { *lib/srcchan:Tick<live!> }
! step t |> lib/srcchan:step-tick(t)
    ! ticked i |> std/io:print.ln("tick {{ i:d }}")
! wait t |> lib/srcchan:interest-tick(t)
    ! polled f |> std/io:print.ln("tick interest fd {{ f:d }}")
! discharge t |> lib/srcchan:close-tick(t): id |> std/io:print.ln("tick retired {{ id:d }}")

std/store:new(tty, capacity: 2) { *lib/srcchan:Src<live!> }
! step s |> lib/srcchan:step-src(s)
    ! moved i |> std/io:print.ln("tty read {{ i:d }}")
    ! waited i |> std/io:print.ln("tty idle {{ i:d }}")
! wait s |> lib/srcchan:interest-src(s)
    ! polled f |> std/io:print.ln("tty interest fd {{ f:d }}")
! discharge s |> lib/srcchan:close-src(s): id |> std/io:print.ln("tty retired {{ id:d }}")

std/store:new(sock, capacity: 2) { *lib/srcchan:Src<live!> }
! step s |> lib/srcchan:step-src(s)
    ! moved i |> std/io:print.ln("sock read {{ i:d }}")
    ! waited i |> std/io:print.ln("sock idle {{ i:d }}")
! wait s |> lib/srcchan:interest-src(s)
    ! polled f |> std/io:print.ln("sock interest fd {{ f:d }}")
! discharge s |> lib/srcchan:close-src(s): id |> std/io:print.ln("sock retired {{ id:d }}")

// One flow — the `|>` chain carries the `<live!>` obligations (a, b, t) through
// to their inserts; a bare `: a` at flow end drops the phantom tracking.
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

// The pump names nothing but itself. Participants JOIN by reference — the
// same shape as `std/store(name) ! field` watches: `std/pump(main)` carries
// the participant's three verbs as `!` arms. Pass order is join order
// (tick first — it delivers the byte the sources read in the same pass).
// `tick-step`/`tick-live`/`tick-wait` are ordinary generated units the
// store's `! step`/`! wait` arms expose — the pump never knows a store
// answered. A hand-written module with the same three tors joins the same
// way.
std/pump:create(main)
| drained |> std/io:print.ln("all participants retired")

std/pump(main)
! step |> tick-step()
! live |> tick-live()
! wait i |> tick-wait(i)

std/pump(main)
! step |> tty-step()
! live |> tty-live()
! wait i |> tty-wait(i)

std/pump(main)
! step |> sock-step()
! live |> sock-live()
! wait i |> sock-wait(i)

// Unarmed `! idle`: the pump's own union-wait runs on dead passes — one poll
// over the interests every joined `! wait` answers (the srcs' fds, the
// tick's 5ms re-poll duration). The "interest fd" lines are the collection
// making itself visible.
std/pump:run(main)
