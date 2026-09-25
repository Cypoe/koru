// PINS: a proto field list takes each name once, same at the default door.
// A `std/proto` block binding `hp` on two lines is a declaration fault the
// door refuses — the merge dedup that unions `<:` field sets is not a license
// to bind one name twice in a single block.
import std/io
import std/proto
import std/list

std/proto(Dup) {
    hp: f32
    hp: f32
}

std/list:new(Dup)
| list xs |> std/io:print.ln("made")
| err e |> std/io:print.ln("ERR {{ e:s }}")
