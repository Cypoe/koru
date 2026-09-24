// PINS: a list carrying ref(T) enforces the same home contract a store
// column does — the proto declares the kind, the program's pluralities
// determine the home set, and the consumer enforces at its own write
// boundary. `dog: 3` is no minted handle: its brand byte names no home,
// so the push traps — the carrier-side twin of 698_012's insert refusal.
import std/proto
import std/store
import std/list

std/proto(Dog) {
    hp: i64
}

std/proto(Owner) {
    name: string
    dog: ref(Dog)
}

std/store:new(dogs, capacity: 8) { Dog }

std/store:insert(dogs) { hp: 7 }
| row d |> std/list:new(Owner)
    | list xs |> std/list:push(xs, name: "a", dog: 3) |> std/list:free(xs)
    | err e |> _
