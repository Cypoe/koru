// PINS: `query(name)` on a capacity-1 VALUE store must name the tier the
// store actually is, not pretend the name is undeclared. The refusal names
// all three spellings — read `game.<field>`, watch `std/store:watch(game)`,
// or declare `capacity: N` for rows — because "unknown plural store" taught
// the agent the name was wrong when the tier was. Measured sub-family of
// KORU161: query() against a declared-but-wrong-tier store.
import std/io
import std/store

std/store:new(game) { entities: 0[i64] }

std/store:query(game) ! row r
|> std/io:print.ln("row {{ r.entities:d }}")
