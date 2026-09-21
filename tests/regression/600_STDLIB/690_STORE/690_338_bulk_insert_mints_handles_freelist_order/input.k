// BULK INSERT WITH HANDLES — a counted `for` insert into a store that
// carries generational handles still lowers to the batched fill. The
// emitted loop mints the SAME slot sequence the per-row path would —
// freelist pops in LIFO order (`free[frem-1-j]`), then bump allocations
// (`next+k`) — so refilled rows carry bit-identical handles and the
// freelist drains in the same order. The only per-row cost that cannot
// be batched is a reactive enter, and that is positional: a rule fires
// for insert sites BELOW its declaration (`__site_line > qs.line`), so
// sites declared ABOVE every rule are provably safe to batch.
//
// `units` carries handles because `snap` names them with `[id]`.
// `fill` and `refill` sit above every rule's declaration — both bulk.
// `tallyfill` sits below `counter`, so it stays per-row and the rule
// fires on each of its inserts: tally lands at 2, proving the reactive
// enters the batch path would have skipped still happen.
//
// The freelist-order pin: cull takes slot 1 (hp 10), cull2 takes slot 3
// (hp 30) — freelist [1, 3]. `refill` pops LIFO: hp 100 mints slot 3,
// hp 200 mints slot 1. `snap` then records each live row's packed handle
// beside its hp; the printed pairs prove which slot each refilled row
// took (generation 1 sits in the high bits of both refilled handles).
import std/io
import std/store
import std/control

std/store:new(units, capacity: 64) { hp: i64 }
std/store:new(seen, capacity: 16) { h: 0[i64], hp: 0[i64] }
std/store:new(tally) { n: 0[i64] }

tor fill {}
fill = for(0..4)
    ! each i |> std/store:insert(units) { hp: @intCast(i * 10) }

tor refill {}
refill = for(0..2)
    ! each i |> std/store:insert(units) { hp: @intCast(100 + i * 100) }

tor counter {}
counter = std/store:rule(units)
! row e when e.hp == 999 |> std/store:stored { tally.n: tally.n + 1 }

tor tallyfill {}
tallyfill = for(0..2)
    ! each _ |> std/store:insert(units) { hp: 999 }

tor cull {}
cull = std/store:rule(units)
! row e when e.hp == 10 |> std/store:take(units[e])
    | item _ |> _

tor cull2 {}
cull2 = std/store:rule(units)
! row e when e.hp == 30 |> std/store:take(units[e])
    | item _ |> _

tor snap {}
snap = std/store:rule(units)
! row { [row]e, [id]h } |> std/store:insert(seen) { h, hp: e.hp }
    | full |> _

fill()
tallyfill()
cull()
cull2()
refill()
snap()

std/io:print.ln("tally {{ tally.n:d }}")
std/io:print.ln("units {{ units.len:d }}")
std/store:query(seen)
! query s |> std/io:print.ln("h {{ s.h:d }} hp {{ s.hp:d }}")
