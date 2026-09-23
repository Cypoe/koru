// 698_011 — a ref() leaf in a store seed must name a declared compound:
// the column lowers to a row handle, and a handle whose target exists
// nowhere is a lie the seed refuses — same gate the proto layer applies
// to its own ref fields (698_007), at the store's own wall.
import std/store

std/store:new(leashes, capacity: 8) { dog: ref(Nope) }
