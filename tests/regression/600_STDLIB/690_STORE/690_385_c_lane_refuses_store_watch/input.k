// PINS a scalar singleton watch lowering on the C lane — the census's
// watch class, lifted. The store:new transform mints a @retain event +
// impl flow per watch arm and calls it from the flat |c write proc after
// the cell settles. What still refuses on C: interceptors, dischargers,
// guarded arms — pinned by 690_386 and siblings. The directory name keeps
// the census numbering; the pin it names moved.
import std/io
import std/store

std/store:new(game) { hp: 0[i64] }

std/store:watch(game)
! hp v |> std/io:print.ln("hp {{ v:d }}")

std/store:stored { game.hp: 4 }
