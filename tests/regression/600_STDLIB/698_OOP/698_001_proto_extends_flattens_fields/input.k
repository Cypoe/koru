// 698_001 — proto extension: `X <: Y` unions the parent's field set into
// the child's entry. Dog <: Animal carries Animal's hp plus its own barked;
// a list of Dog takes the merged record at the push boundary and hands the
// inherited field back on pop.
import std/io
import std/proto
import std/list

std/proto(Animal) {
    hp: i64
}

std/proto(Dog <: Animal) {
    barked: bool
}

std/list:new(Dog)
| list xs |> std/list:push(xs, hp: 7, barked: true) |> std/list:pop(xs)
    | item v |> std/io:print.ln("hp={{ v.hp:d }}") |> std/list:free(xs)
    | empty  |> std/io:print.ln("EMPTY") |> std/list:free(xs)
| err e |> std/io:print.ln("ERR {{ e:s }}")
