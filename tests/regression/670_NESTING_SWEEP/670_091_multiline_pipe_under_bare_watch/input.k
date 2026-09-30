// NESTING SWEEP — the equal-indent multi-line `|>` continuation under a
// BARE `std/store(name)` reactive attach, the sibling spelling of
// `std/store:watch(name)` whose multi-line arm 220_017 already pins. A
// [pre]-phase rewrite renames the bare `default` invocation to `watch`
// (690_025 header), so the arm machinery — including the multi-line `|>`
// continuation parse that the duplicate-branch-handler check once misread
// — must treat both spellings identically.
//
// Two `!` arms hang off the one attach; the FIRST arm's body is the
// multi-line chain, so continuation lines sit between the `! hp` arm and
// its `! mana` sibling — the exact arrangement a stale "continuation line
// is a duplicate handler" misparse would corrupt.
//
// Grounds: bare-attach spelling `std/store(game) ! hp h |> …` (690_025;
// guarded 690_026; plural 690_030); multi-line `|>` under
// `std/store:watch` (220_017). Three writes: hp=5 fires the hp arm
// (a / b / hp 5), mana=2 fires the mana arm (mana 2), hp=7 fires the hp
// arm again (a / b / hp 7).
import std/io
import std/store

std/store:new(game) { hp: 0[i64], mana: 0[i64] }

std/store(game)
! hp h |> std/io:print.ln("a")
    |> std/io:print.ln("b")
    |> std/io:print.ln("hp {{ h:d }}")
! mana m |> std/io:print.ln("mana {{ m:d }}")

std/store:stored { game.hp: 5 }
std/store:stored { game.mana: 2 }
std/store:stored { game.hp: 7 }
