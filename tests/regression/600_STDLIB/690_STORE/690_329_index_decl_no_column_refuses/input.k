// PINS: the REFUSAL of a column-less `std/indexes:store` declaration.
// `std/indexes:store(players)` names a store but no column — the discovery
// read that the same as "no declaration": no field, no machinery, no
// diagnostic, a dead claim the author believes is live. An index keys on
// ONE column of the store; a declaration that omits it is refused at the
// declaration's own location.

import std/store
import std/indexes
import std/io

std/store:new(players, capacity: 8) { key: i64 }
std/indexes:store(players)

std/io:print.ln("unreachable")
