// PINS the C-lane refusal for ref() home columns — the typed-edge cell
// (row handle of another store's proto) is outside the C lane's first
// fragment.
import std/io
import std/proto
import std/store

std/proto(Dog) {
    hp: i64
}

std/store:new(dogs, capacity: 8) { Dog }
std/store:new(leashes, capacity: 8) { dog: ref(Dog) }

std/store:insert(dogs) { hp: 7 }
| row d |> std/io:print.ln("ref store up")
