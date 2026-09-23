// 698_015 — `-1` is the store's standing unset sentinel (tree `parent`
// defaults to it): a `ref(Dog)` column accepts it as "no reference" —
// the home check gates handles, not the absence of one.
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

std/store:insert(owners) { dog: -1 }

std/store:query(owners)
! query o |> std/io:print.ln("dog {{ o.dog:d }}")
