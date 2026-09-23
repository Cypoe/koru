// 698_010 — pure inheritance needs no body: `X <: Y` with no block is a
// proto carrying exactly the parent's field set. The transform declares
// `source: ?Source` — the first optional-Source param — so a blockless
// declaration reaches the handler with source null rather than skipping
// it in silence.
import std/io
import std/proto
import std/list

std/proto(Animal) {
    hp: i64
}

std/proto(Cat <: Animal)

std/list:new(Cat)
| list xs |> std/list:push(xs, hp: 9) |> std/list:pop(xs)
    | item v |> std/io:print.ln("hp={{ v.hp:d }}") |> std/list:free(xs)
    | empty  |> std/io:print.ln("EMPTY") |> std/list:free(xs)
| err e |> std/io:print.ln("ERR {{ e:s }}")
