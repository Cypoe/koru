// CHALLENGE 800_008 — "relay": one resource at a time across a module
// seam, retagged by Koru on the far side.
//
// The catalog's runnable rows all hammer the same shape — a bulk-
// populated store swept by verbs. This one has no population at all.
// A single *Pouch is minted in lib/post.kz, carried through a
// sign → wax → carry → arrive stamp chain implemented in lib/stamps.k
// (pure Koru — no proc touches the phantom), and filed back in post's
// discharger. Two module boundaries per dispatch; the obligation does
// the travelling.
//
// The retry is the interesting bend: every third dispatch is
// challenged at the pass — `turn-back` consumes <!carried> and
// re-issues <sealed!>, a BACKWARD retag on a foreign pointer, and the
// recursive `route` carries it out again. The same pointer crosses the
// seam in both directions before it can be filed.
//
// Ledger discipline rides along: `board` counts sent / turned / filed,
// and a scalar line token keeps run-order a type property —
// open → run → seal → close.

import std/io
import std/store
import app/lib/post
import app/lib/stamps

// ── the line token — run order is a type property ────────────────

tor open-line { n: i64 } -> i64<open!>
open-line -> n

tor seal-line { g: i64<!open> } -> i64<closed!>
seal-line -> g

tor close-line { g: i64<!closed> } -> i64
close-line -> g

// ── the ledger ───────────────────────────────────────────────────

std/store:new(board) { sent: 0[i64], turned: 0[i64], filed: 0[i64] }

// ── the route — recursive retry across the seam ──────────────────

tor route { p: *app/lib/post:Pouch<!carried>, bounced: i64, id: i64 }
route = if(bounced == 0 and @mod(id, 3) == 0)
    | then |> std/io:print.ln("dispatch {{ id:d }} challenged at the pass — returned to depot")
        |> std/store:stored { board.turned: board.turned + 1 }
        |> app/lib/stamps:turn-back(p): p1
        |> app/lib/stamps:sign(p: p1): p2
        |> app/lib/stamps:wax(p: p2): p3
        |> app/lib/stamps:carry(p: p3): p4
        |> route(p: p4, bounced: 1, id)
    | else |> app/lib/post:peek-seal(p): s
        |> std/io:print.ln("dispatch {{ id:d }} arrived — seal {{ s:d }} intact")
        |> app/lib/stamps:arrive(p): p3
        |> app/lib/post:file-dispatch(p: p3)
        |> std/store:stored { board.filed: board.filed + 1 }

// ── the run ──────────────────────────────────────────────────────
// Every fourth pouch goes express — carried straight off the desk
// through carry's union-consume, no sign, no wax. Dispatch 0 is both
// express AND challenged: it re-enters <held!> and runs the full
// stamp chain on the way back out. Each arm counts its own send —
// see 800_009 for why the count can't ride a |> continuation past
// the if (an obligation consumed in both arms is still 'live' at
// the merge — the frontier this program pinned).

tor send-all { n: i64<*> }
send-all = for(0..@as(usize, @intCast(n)))
    ! each i |> app/lib/post:took-pouch(seal: @as(i64, @intCast(i))): p
        |> if(@mod(@as(i64, @intCast(i)), 4) == 0)
            | then |> std/io:print.ln("dispatch {{ i:d }} sent express")
                |> std/store:stored { board.sent: board.sent + 1 }
                |> app/lib/stamps:carry(p): p1
                |> route(p: p1, bounced: 0, id: @as(i64, @intCast(i)))
            | else |> std/store:stored { board.sent: board.sent + 1 }
                |> app/lib/stamps:sign(p): p1
                |> app/lib/stamps:wax(p: p1): p2
                |> app/lib/stamps:carry(p: p2): p3
                |> route(p: p3, bounced: 0, id: @as(i64, @intCast(i)))

tor run-line { g: i64<!open> } -> i64<closed!>
run-line = send-all(n: g) |> seal-line(g): gg -> gg

open-line(n: 9): g
|> run-line(g): g1
|> close-line(g: g1): r
|> std/io:print.ln("relay closed: {{ r:d }} dispatched, {{ board.turned:d }} turned back, {{ board.filed:d }} filed")
