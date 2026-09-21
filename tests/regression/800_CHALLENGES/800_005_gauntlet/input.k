// CHALLENGE 800_005 — "gauntlet": a phantom-phased combat arena.
//
// Two obligation axes carry the structure. The Gauntlet phases are pure
// Koru — no proc touches them. The Unit token's mint/kill are leaf procs
// (a resource edge), which is where procs belong.
//   1. The Gauntlet token — an i64<open!> → <mustered!> → <fought!> →
//      <scored!> chain, closed by a consumer of i64<!scored>. Each phase
//      tor consumes the previous state and produces the next, so phase
//      order is a type property; the run cannot close un-scored.
//   2. The Unit token — every combatant's `u` column is a
//      *Unit<live!> minted by spawn-unit and dischargeable ONLY through
//      kill-unit, which is the column's canonical void discharger — so
//      the store auto-discharges it on every death (rule+take) and at
//      teardown. No combatant can leave the world unkilled.
//
// The workload is the measured hot path: counted-for bulk insert, handle
// mint + grid pairing, indexed-resolve writes (arena[a.opp] and the
// respelled `arena[i.opp]` in a take item arm), guarded sweep-take with
// swap-remove revisit, the interceptor arms (inserted / removed /
// discharge), a standing `hp` watch, and a first-match extraction take
// followed by a deliberate stale-handle `| empty`.

import std/io
import std/store
import std/grid
import app/lib/unit

// ── the gauntlet token — phase order is a type property ──────────

tor open-gauntlet { rounds: i64 } -> i64<open!>
open-gauntlet -> rounds

tor seal-muster { g: i64<!open> } -> i64<mustered!>
seal-muster -> g

tor seal-fight { g: i64<!mustered> } -> i64<fought!>
seal-fight -> g

tor seal-score { g: i64<!fought> } -> i64<scored!>
seal-score -> g

tor seal-honor { g: i64<!scored> } -> i64<honored!>
seal-honor -> g

tor close-gauntlet { g: i64<!honored> } -> i64
close-gauntlet -> g

// ── the arena — reactive board rides the write paths ─────────────

std/store:new(board) { alive: 0[i64], kills: 0[i64], pool: 0[i64], chk: 0[i64], seen: 0[i64], scar: 0[i64] }

std/store:new(arena, capacity: 32) { u: *app/lib/unit:Unit<live!>, hp: i64, atk: i64, opp: i64 }
! inserted { hp } |> std/store:stored { board.alive: board.alive + 1 } |> std/store:stored { board.pool: board.pool + hp }
! removed { hp } |> std/store:stored { board.alive: board.alive - 1 } |> std/store:stored { board.kills: board.kills + 1 } |> std/store:stored { board.pool: board.pool - hp } |> std/io:print.ln("culled a foe at {{ hp:d }} hp")

std/store(board)
! kills k |> std/io:print.ln("board: {{ k:d }} killed")

// A field watch rides the hot write path: every `hp` write — strike,
// vigor, champion extraction — lands a scar. Transplanted, not queried.
std/store(arena)
! hp h |> std/store:stored { board.scar: board.scar + h }

std/grid:new(order, size: 32) { h: -1[i64] }

// ── phases — pure Koru flows between leaf relabels ───────────────

tor spawn-wave {}
spawn-wave = for(0..@as(usize, 32))
    ! each i |> app/lib/unit:spawn-unit(id: @as(i64, @intCast(i))): u
        |> std/store:insert(arena) { u, hp: 20 + @mod(@as(i64, @intCast(i)), 5), atk: 3 + @mod(@as(i64, @intCast(i)), 3), opp: -1 }
        | row h |> std/grid:stored { order[i].h: h }
        | full _ |> _

tor pair-rivals {}
pair-rivals = for(0..@as(usize, 32))
    ! each i |> std/store:stored { arena[order[i].h].opp: order[31 - i].h }

// A duel ends when a rival falls: cull clears the survivor's back-pointer
// (opp: -1 = "no rival") before the dead row's handle could go stale, and
// strike stands down on -1 — resolving a removed handle is the stale trap
// (690_115), not a skip.

// The dead don't strike: a compound guard holds a corpse's blade even
// before the cull sweeps it (strike precedes cull inside a round).
tor strike {}
strike = std/store:query(arena)
! query a when a.opp != -1 and a.hp > 0 |> std/store:stored { arena[a.opp].hp: arena[a.opp].hp - a.atk }

// The survivor takes the rival's vigor: a second write through the SAME
// `i.opp` payload handle — the respell-index path, twice per cull arm.
tor cull {}
cull = std/store:rule(arena)
! row e when e.hp <= 0 |> std/store:take(arena[e])
    | item i |> if(i.opp != -1)
        | then |> std/store:stored { arena[i.opp].opp: -1 }
            |> std/store:stored { arena[i.opp].hp: arena[i.opp].hp + 5 }
        | else |> _

tor rounds { left: i64 } -> i64
rounds = strike() |> cull() |> if(left <= 1)
    | then -> 1
    | else |> rounds(left: left - 1): r -> r + 1

tor muster { g: i64<!open> } -> i64<mustered!>
muster = spawn-wave() |> pair-rivals() |> seal-muster(g): gg -> gg

tor fight { g: i64<!mustered> } -> i64<fought!>
fight = rounds(left: g): n |> std/io:print.ln("fought {{ n:d }} rounds")
    |> seal-fight(g): gg -> gg

tor tally {}
tally = std/store:query(arena)
! query a |> std/store:stored { board.chk: board.chk + a.hp }
    |> std/store:stored { board.seen: board.seen + 1 }

tor score { g: i64<!fought> } -> i64<scored!>
score = tally() |> std/io:print.ln("score {{ board.chk:d }} over {{ board.seen:d }} survivors, {{ board.scar:d }} scarred")
    |> seal-score(g): gg -> gg

// ── honor — first-match take, then the double-take miss ──────────
// `! first` extracts the front survivor mid-query (the take under a
// query arm, 690_305). The challenger is minted, taken, and taken
// AGAIN — the second take resolves a stale handle into `| empty`
// (690_070's graceful absence, not the stale-write trap).

tor honor-champion {}
honor-champion = std/store:query(arena)
    ! first a when a.hp > 0 |> std/store:take(arena[a])
        | item c |> std/io:print.ln("champion stands down at {{ c.hp:d }} hp")
        | empty |> std/io:print.ln("champion slipped away")
    | none |> std/io:print.ln("no survivors to honor")

tor honor-challenger {}
honor-challenger = app/lib/unit:spawn-unit(id: 99): cu
    |> std/store:insert(arena) { u: cu, hp: 1, atk: 0, opp: -1 }
        | row ch |> std/store:take(arena[ch])
            | item _ |> std/store:take(arena[ch])
                | item _ |> std/io:print.ln("a ghost struck back")
                | empty |> std/io:print.ln("the dead stay dead")
            | empty |> std/io:print.ln("challenger never stood")
        | full _ |> std/io:print.ln("no room for a challenger")

tor honor { g: i64<!scored> } -> i64<honored!>
honor = honor-champion() |> honor-challenger() |> seal-honor(g): gg -> gg

// ── the run ──────────────────────────────────────────────────────

open-gauntlet(rounds: 6): g
|> muster(g): g1
|> fight(g: g1): g2
|> score(g: g2): g3
|> honor(g: g3): g4
|> close-gauntlet(g: g4): r
|> std/io:print.ln("gauntlet closed after {{ r:d }} rounds")
