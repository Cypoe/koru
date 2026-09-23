// 698_009 — a ref field in a store seed lowers to the handle column:
// `dog: ref(Dog)` declares the typed edge (the create-site marker keeps
// the target for the checker) and the column material is i64 — the row
// handle, insertable and derefable through the bracket head, same as the
// self-FK substrate 690_048 pins with a bare `i64`.
import std/proto
import std/store
import std/io

std/proto(Dog) {
    hp: i64
}

std/proto(Owner) {
    dog: ref(Dog)
}

std/store:new(dogs, capacity: 8) { Dog }
std/store:new(owners, capacity: 8) { Owner }

// The ref leaf is also legal directly in the seed (no proto member).
std/store:new(leashes, capacity: 8) { dog: ref(Dog) }

std/store:insert(dogs) { hp: 7 }
| row d |> std/store:insert(owners) { dog: d }
    | row _ |> std/store:insert(leashes) { dog: d }

// Follow the typed edge: the owners row's `dog` column IS a dogs handle —
// the bracket head derefs it straight to the Dog row.
std/store:query(owners)
! query o |> std/store:stored { dogs[o.dog].hp: 42 }

std/store:query(dogs)
! query e |> std/io:print.ln("hp {{ e.hp:d }}")
