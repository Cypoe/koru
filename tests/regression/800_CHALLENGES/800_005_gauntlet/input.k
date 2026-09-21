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
// mint + grid pairing, indexed-resolve writes (arena[a.opp]), guarded
// sweep-take with swap-remove revisit, and the interceptor arms
// (inserted / removed / discharge) feeding a reactive board.

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

tor close-gauntlet { g: i64<!scored> } -> i64
close-gauntlet -> g

// ── the arena — reactive board rides the write paths ─────────────

std/store:new(board) { alive: 0[i64], kills: 0[i64], pool: 0[i64], chk: 0[i64], seen: 0[i64] }

std/store:new(arena, capacity: 32) { u: *app/lib/unit:Unit<live!>, hp: i64, atk: i64, opp: i64 }
! inserted { hp } |> std/store:stored { board.alive: board.alive + 1 } |> std/store:stored { board.pool: board.pool + hp }
! removed { hp } |> std/store:stored { board.alive: board.alive - 1 } |> std/store:stored { board.kills: board.kills + 1 } |> std/store:stored { board.pool: board.pool - hp } |> std/io:print.ln("culled a foe at {{ hp:d }} hp")

std/store(board)
! kills k |> std/io:print.ln("board: {{ k:d }} killed")

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

tor strike {}
strike = std/store:query(arena)
! query a when a.opp != -1 |> std/store:stored { arena[a.opp].hp: arena[a.opp].hp - a.atk }

tor cull {}
cull = std/store:rule(arena)
! row e when e.hp <= 0 |> std/store:take(arena[e])
    | item i |> if(i.opp != -1)
        | then |> std/store:stored { arena[i.opp].opp: -1 }
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
score = tally() |> std/io:print.ln("score {{ board.chk:d }} over {{ board.seen:d }} survivors")
    |> seal-score(g): gg -> gg

// ── the run ──────────────────────────────────────────────────────

open-gauntlet(rounds: 6): g
|> muster(g): g1
|> fight(g: g1): g2
|> score(g: g2): g3
|> close-gauntlet(g: g3): r
|> std/io:print.ln("gauntlet closed after {{ r:d }} rounds")
