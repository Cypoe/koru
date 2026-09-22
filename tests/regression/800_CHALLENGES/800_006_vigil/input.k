// CHALLENGE 800_006 — "vigil": sparse membership over a sleeping watch.
//
// Where 800_005 hammered dense sweeps, this one is the sparse shape the
// ecs-store board measured at 2.03x striped: 64 sentries, 1/8 awake —
// every guarded sweep visits all and touches few. Around it, the
// surfaces the gauntlet could not carry:
//
//   - a cross-store guarded watch (690_013) on a PLURAL target — writing
//     `board.alarm` re-announces `sentries.fatigue` on every live row
//     through a synthesized per-row sweep (690_340). (`! updated` is a
//     documented later-slice: it refuses to share a store with any field
//     watch, so it is not in this challenge.)
//   - `std/store:clear` + `! cleared n` — mass emptying; the next
//     insert proves the generation bump (690_265's contract). On an
//     OWNED column `clear` is refused by ruling — obligations discharge
//     one at a time — so `relics` drains through a take-only rule
//     (the 690_336 drain sweep), each `| item` releasing through the
//     canonical `release-relic`.
//   - `| none` — the sparse query's empty-match arm, hit once the last
//     sentry collapses.
//
// Phase order is again a type property: `dusk! → night! → dawn!`,
// closed by a consumer of i64<!dawn>.

import std/io
import std/store
import app/lib/relic

// ── the vigil token ──────────────────────────────────────────────

tor dusk-vigil { rounds: i64 } -> i64<dusk!>
dusk-vigil -> rounds

tor seal-night { g: i64<!dusk> } -> i64<night!>
seal-night -> g

tor seal-dawn { g: i64<!night> } -> i64<dawn!>
seal-dawn -> g

tor close-vigil { g: i64<!dawn> } -> i64
close-vigil -> g

// ── the watch — sparse membership, delta ledger, gated reports ───

std/store:new(board) { toll: 0[i64], fell: 0[i64], gone: 0[i64], alarm: 0[i64] }

std/store:new(sentries, capacity: 64) { awake: i64, fatigue: i64, post: i64 }
! removed _ |> std/store:stored { board.fell: board.fell + 1 }
! cleared n |> std/io:print.ln("watch dismissed, {{ n:d }} posts cleared")

std/store:new(relics, capacity: 16) { r: *app/lib/relic:Relic<held!>, worth: i64 }

// The alarm gates the fatigue report — a watch guarded across stores on a
// PLURAL target: writing `board.alarm` must re-announce `fatigue` on EVERY
// live sentry row through the synthesized per-row sweep (690_340).
std/store(sentries)
! fatigue f when board.alarm == 1 |> std/io:print.ln("fatigue {{ f:d }}")

// ── phases ───────────────────────────────────────────────────────

tor muster {}
muster = for(0..@as(usize, 64))
    ! each i |> std/store:insert(sentries) { awake: if (@mod(@as(i64, @intCast(i)), 8) == 0) 1 else 0, fatigue: 0, post: @as(i64, @intCast(i)) }
        | row _ |> _
        | full |> _

tor mint-relics {}
mint-relics = for(0..@as(usize, 8))
    ! each i |> app/lib/relic:mint-relic(id: @as(i64, @intCast(i))): r
        |> std/store:insert(relics) { r, worth: 10 + @as(i64, @intCast(i)) }
            | row _ |> _
            | full _ |> _

// The sparse sweep: 64 visited, 8 written.
tor patrol {}
patrol = std/store:query(sentries)
! query s when s.awake == 1 |> std/store:stored { s.fatigue: s.fatigue + 7 }

tor collapse {}
collapse = std/store:rule(sentries)
! row s when s.fatigue >= 28 |> std/store:take(sentries[s])
    | item i |> std/io:print.ln("post {{ i.post:d }} stands down at {{ i.fatigue:d }}")

tor commander {}
commander = std/store:query(sentries)
    ! first s when s.awake == 1 |> std/io:print.ln("post {{ s.post:d }} holds the watch")
    | none |> std/io:print.ln("all asleep")

tor rounds { left: i64 } -> i64
rounds = patrol() |> collapse() |> commander() |> if(left <= 1)
    | then -> 1
    | else |> rounds(left: left - 1): r -> r + 1

tor stand-watch { g: i64<!dusk> } -> i64<night!>
stand-watch = muster() |> mint-relics() |> rounds(left: g): n
    |> std/io:print.ln("kept {{ n:d }} rounds")
    |> seal-night(g): gg -> gg

// Dawn raises the alarm and stripes the corpus — every watch report
// the night suppressed arrives at once. The relics drain through a
// take-only rule (each `| item` auto-discharging its *Relic<held!>
// through release-relic), the watch dismisses in one `clear`, and a
// fresh mint into the cleared store proves the generation bump.
tor release-relics {}
release-relics = std/store:rule(relics)
! row x |> std/store:take(relics[x])
    | item it |> std/store:stored { board.gone: board.gone + 1 }
        |> std/io:print.ln("relic of worth {{ it.worth:d }} released")

tor dawn-sentry {}
dawn-sentry = std/store:insert(sentries) { awake: 0, fatigue: 0, post: 99 }
    | row _ |> _
    | full |> _

tor dawn { g: i64<!night> } -> i64<dawn!>
dawn = std/store:stored { board.alarm: 1 }
    |> release-relics()
    |> std/store:clear(sentries)
    |> dawn-sentry()
    |> seal-dawn(g): gg -> gg

// ── the run ──────────────────────────────────────────────────────

dusk-vigil(rounds: 5): g
|> stand-watch(g): g1
|> dawn(g: g1): g2
|> close-vigil(g: g2): r
|> std/io:print.ln("vigil closed after {{ r:d }} rounds: {{ board.toll:d }} tolled, {{ board.fell:d }} fell, {{ board.gone:d }} relics gone")
