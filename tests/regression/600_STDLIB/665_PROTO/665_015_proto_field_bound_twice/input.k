// PINS: a proto field list takes each name once. A `std/types:proto` block
// binding `rpm` on two lines is a declaration fault the door refuses — the
// derived container would otherwise emit the name twice into one struct.
import std/io
import std/types
import std/list

std/types:proto(Dup) {
    rpm: i32
    rpm: i32
}

std/list:new(Dup)
| list xs |> std/io:print.ln("made")
| err e |> std/io:print.ln("ERR {{ e:s }}")
