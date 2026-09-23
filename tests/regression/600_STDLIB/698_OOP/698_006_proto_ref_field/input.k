// 698_006 — ref field kind: `dog: ref(Dog)` declares a typed row
// reference. The field lowers to the store's i64 handle material while the
// marker keeps the target name for checkers — a list of Owner carries it.
import std/io
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
| list xs |> std/list:push(xs, name: "a", dog: 3) |> std/list:pop(xs)
    | item v |> std/io:print.ln("dog={{ v.dog:d }}") |> std/list:free(xs)
    | empty  |> std/io:print.ln("EMPTY") |> std/list:free(xs)
| err e |> std/io:print.ln("ERR {{ e:s }}")
