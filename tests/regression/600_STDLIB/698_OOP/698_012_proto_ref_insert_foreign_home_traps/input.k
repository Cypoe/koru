// 698_012 — a `ref(Dog)` column refuses a handle minted by a store that
// does not hold Dog rows. `cats` rows carry `lives`, not Dog's `hp`, so a
// cats handle is a foreign home: the write traps at the insert, naming the
// column and its declared target — the deref-side brand trap (690_196)
// would only fire later, far from the fault.
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
std/store:new(cats, capacity: 8) { lives: i64 }
std/store:new(owners, capacity: 8) { Owner }

std/store:insert(cats) { lives: 9 }
| row c |> std/store:insert(owners) { dog: c }
