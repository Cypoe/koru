// `! step` this rung lives on a ONE-OWNED-COLUMN store — the row IS its
// obligation, which is what lets `| complete` retire it. On a store whose
// columns carry no obligation the arm refuses: a `complete` verdict would
// have nothing to drain and no owned row to retire.
import std/io
import std/store

std/store:new(pool, capacity: 4) { hp: i64 }
! step p |> std/io:print.ln("hp {{ p:d }}")
