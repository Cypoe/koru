// PINS the C-lane refusal for store watches — the census's watch class.
// Under --lang=c the store:new transform names the gate — singleton
// stores: watches/interceptors/dischargers are outside the C lane's first fragment
// (store.new.kz). Zig leg must still pass — the refusal is a lane
// boundary, not a language error.
import std/io
import std/store

std/store:new(game) { hp: 0[i64] }

std/store:watch(game)
! hp v |> std/io:print.ln("hp {{ v:d }}")

std/store:stored { game.hp: 4 }
