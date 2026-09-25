// PINS: a seed entry with no name — `: 0[i64]` — is a malformed field, not a
// column named ''. The shared field parser refuses it (KORU161) instead of
// letting the empty name downstream into branch-coverage errors.
import std/io
import std/store

std/store:new(tasks, capacity: 4) { : 0[i64], m: 0[i64] }

std/io:print.ln("unreachable")
