// 698_014 — the home check is a field-set subsumption, not a name match:
// `Pup <: Dog` flattens Dog's fields into Pup, so a `pups` store holds Dog
// rows and its handles pass the `ref(Dog)` gate. The handle then derefs
// through the store that minted it.
import std/proto
import std/store
import std/io

std/proto(Dog) {
    hp: i64
}

std/proto(Pup <: Dog) {
    weight: i64
}

std/proto(Owner) {
    dog: ref(Dog)
}

std/store:new(pups, capacity: 8) { Pup }
std/store:new(owners, capacity: 8) { Owner }

std/store:insert(pups) { hp: 7, weight: 2 }
| row p |> std/store:insert(owners) { dog: p }

std/store:query(owners)
! query o |> std/io:print.ln("hp {{ pups[o.dog].hp:d }}")
