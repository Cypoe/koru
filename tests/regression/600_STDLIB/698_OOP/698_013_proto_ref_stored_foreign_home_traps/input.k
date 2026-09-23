// 698_013 — the same home check guards `stored` writes: a `ref(Dog)`
// column written through the apply dispatcher refuses a handle minted by
// a store that does not hold Dog rows. The owner row starts unset (-1),
// then a cats handle is stored into it — the trap fires at the write.
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
| row c |> std/store:insert(owners) { dog: -1 }
    | row o |> std/store:stored { owners[o].dog: c }
