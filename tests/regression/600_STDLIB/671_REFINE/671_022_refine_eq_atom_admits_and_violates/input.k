// Test: the `==N` atom — the fifth bound kind the module header lists —
// parses, meets onto a proto field, prints its canonical form, and is
// enforced at the list boundary: `==8080` admits 8080 and refuses 80.
//
// Expected: Stage C prints the canonical meet with the equality
//           (expected_comptime); runtime prints `accepted` then
//           `rejected port`.
import std/proto
import std/refine
import std/list
import std/io

std/proto(Server) {
    port: i64
    host: string
}

std/refine(Server) {
    port: i64 & ==8080
    host: string
}

std/list:new(Server)
| list xs |> std/list:push(xs, port: 8080, host: "web-01")
    | ok |> std/io:print.ln("accepted") |> std/list:free(xs)
    | violated f |> std/io:print.ln("rejected {{ f:s }}") |> std/list:free(xs)
| err e |> std/io:print.ln("ERR {{ e:s }}")

std/list:new(Server)
| list ys |> std/list:push(ys, port: 80, host: "web-01")
    | ok |> std/io:print.ln("accepted-wrong") |> std/list:free(ys)
    | violated f |> std/io:print.ln("rejected {{ f:s }}") |> std/list:free(ys)
| err e |> std/io:print.ln("ERR {{ e:s }}")
