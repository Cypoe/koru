// 698_004 — same name, same concept: restating an inherited field verbatim
// dedups instead of conflicting. `hp: i64` on Dog <: Animal is the SAME
// concept Animal already declared — one field, not two, and not an error.
import std/io
import std/proto
import std/list

std/proto(Animal) {
    hp: i64
}

std/proto(Dog <: Animal) {
    hp: i64
}

std/list:new(Dog)
| list xs |> std/list:push(xs, hp: 7) |> std/list:len(xs): n |> std/io:print.ln("len={{ n:d }}") |> std/list:free(xs)
| err e |> std/io:print.ln("ERR {{ e:s }}")
