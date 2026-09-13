// PINS: two modules arming `std/store:query` on the SAME store at the SAME
// source line must mint distinct synthesized units. Query/sweep structs land
// in the STORE's home scope (sim), so a name keyed on store+line alone
// collides the moment a second file arms `items` on the same line — both
// files here carry their `! query` arm on line 14.
import std/io
import sim
import ext

sim:seed() |> sim:dump-sim() |> ext:dump-ext()
