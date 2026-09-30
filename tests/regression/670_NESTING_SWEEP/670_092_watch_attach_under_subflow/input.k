// NESTING SWEEP — a `std/store:watch(name)` standing attach nested as the
// body of a `=` SUBFLOW (`w = std/store:watch(c)`), the sibling form of the
// anonymous top-level attach 220_017/690_001 pin. The store transform
// collects watch flows by walking program items (koru_std/store.kz,
// `~part watch`); this pins that the walk still finds — and splices — a
// watch whose lexical home is a subflow body, and that the attach needs no
// `w()` call: the watch is compile-time write-path fusion, not an
// invocation.
//
// Grounds: `name = <store op with ! arms>` subflow impls
// (800_006 release-relics = std/store:rule + `! row`; 800_005 strike =
// std/store:query + `! query`); anonymous top-level watch attach + `! v x`
// arm (220_017, 690_025). `w` is never called — the pin is that the attach
// still happens (watched 1), not that calling `w()` triggers it.
import std/io
import std/store

std/store:new(c) { v: 0[i64] }

tor w {}
w = std/store:watch(c)
! v x |> std/io:print.ln("watched {{ x:d }}")

std/store:stored { c.v: 1 }
