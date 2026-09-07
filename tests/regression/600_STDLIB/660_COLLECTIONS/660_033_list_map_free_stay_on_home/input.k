// A list op-transform is qualified-only: `std/list:free` must not rewrite
// `std/map:free` onto the list trunk (`std.map:free-i64`, 810_142). Both
// collections live in one program; each free stays on its own home.
import std/io
import std/list
import std/map

std/list:new-i64()
| list xs |> std/list:push(xs, v: 1) |> std/map:new()
    | map m |> std/map:set(m, k: 1, v: 10) |> std/map:get(m, k: 1)
        | value v |> std/io:print.ln("{{ v:d }}") |> std/list:free(xs) |> std/map:free(m)
        | missing |> std/io:print.ln("MISSING") |> std/list:free(xs) |> std/map:free(m)
    | err _ |> std/io:print.ln("E2") |> std/list:free(xs)
| err _ |> std/io:print.ln("E1")
