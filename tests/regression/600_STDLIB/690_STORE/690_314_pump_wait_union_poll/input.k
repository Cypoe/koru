// `! wait` on `std/store:new` — the interest contract. Where `! step` asks
// "advance this row once", `! wait` answers "what would you block on": the
// callee's return type IS the vocabulary — `i32` answers a descriptor to
// poll, `i128` a relative re-poll duration, `{ fd, wait_ns }` both.
//
// A `pump:run` with no `! idle` arm composes the wait itself: when a pass
// steps every live row and nobody progresses (no `| running` or `| complete`
// — the only two words the pump reads; `| quiet` here is an author-named
// no-progress verdict), the pump collects one interest record per live row
// and blocks ONCE — poll() over every declared fd, capped by the nearest
// wait_ns. That is the composition seam for blocking-shaped participants:
// two sources on real socketpair fds plus a deadline-only tick share one
// thread and one kernel wait.
//
// Pinned: the interest-collection lines appear exactly on the all-idle
// passes (twice while all three live, twice after both sources retire), the
// step ordering stays declared-order, and the pump still drains to `drained`.
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

// tick joins FIRST — it delivers the byte the sources read in the same pass.
// `std/pump(main)` is the join form: the participant's verbs arrive as `!`
// arms, and the stores' `! step`/`! wait` arms already exposed them as the
// ordinary units `<store>-step`/`<store>-live`/`<store>-wait`.
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
