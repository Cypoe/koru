// PINS: a name bound twice is a fault wherever the field lines live — an
// entry extended through `<:` cannot inherit around it. `Animal` binds `name`
// twice; the refusal fires whether the child merges the still-live block or
// the parent's own gate has already erased it.
import std/io
import std/proto
import std/list

std/proto(Animal) {
    name: string
    name: string
}

std/proto(Dog <: Animal) {
    bark: i32
}

std/list:new(Dog)
| list xs |> std/io:print.ln("made")
| err e |> std/io:print.ln("ERR {{ e:s }}")
