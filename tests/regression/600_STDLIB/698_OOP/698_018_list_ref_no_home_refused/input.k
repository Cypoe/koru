// PINS: ref(T) with no possible home refuses at list:new — the same law
// as 698_016 on the store side. A field that can only ever hold -1 is
// not honoring the contract; it is voiding it.
import std/proto
import std/list

std/proto(Dog) {
    hp: i64
}

std/proto(Owner) {
    name: string
    dog: ref(Dog)
}

std/list:new(Owner)
| list xs |> std/list:free(xs)
| err e |> _
