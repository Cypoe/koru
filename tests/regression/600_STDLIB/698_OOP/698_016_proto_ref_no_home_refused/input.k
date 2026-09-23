// 698_016 — `ref(Ghost)` where Ghost is declared but no store holds its
// field set refuses at create: the column could only ever hold -1, which
// is a declaration bug, not a runtime state. Distinct from 698_011
// (unknown proto target) — here the target exists but has no home.
import std/proto
import std/store

std/proto(Ghost) {
    hp: i64
}

std/store:new(refs, capacity: 4) {
    g: ref(Ghost)
}
