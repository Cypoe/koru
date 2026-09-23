// 698_002 — multiple extension: `X <: A + B` unions both parents' field
// sets. The diamond resolves by name-sameness: two parents naming the same
// concept merge into one column, never two.
import std/io
import std/proto
import std/list

std/proto(Animal) {
    hp: i64
}

std/proto(Pet) {
    tag: string
}

std/proto(Dog <: Animal + Pet) {
    barked: bool
}

std/list:new(Dog)
| list xs |> std/list:push(xs, hp: 7, tag: "rex", barked: true) |> std/list:pop(xs)
    | item v |> std/io:print.ln("hp={{ v.hp:d }} tag={{ v.tag:s }}") |> std/list:free(xs)
    | empty  |> std/io:print.ln("EMPTY") |> std/list:free(xs)
| err e |> std/io:print.ln("ERR {{ e:s }}")
