// PINS: the REFUSAL of a second `std/indexes:store` declaration naming the
// same store. One index per store is the ruling today — a second
// declaration used to be silently dropped (the discovery walk returned the
// first match and nothing else looked), which is the banned silent-drop:
// the author believes `val` is indexed and `! first` on it scans forever.
// The store's own emit site refuses at the second declaration's location.
//
// Same ruling covers a re-declaration of the same column — any second
// claim on the store is refused, not just a different-column one.

import std/store
import std/indexes
import std/io

std/store:new(players, capacity: 8) { key: i64, val: i64 }
std/indexes:store(players, key)
std/indexes:store(players, val)

std/io:print.ln("unreachable")
