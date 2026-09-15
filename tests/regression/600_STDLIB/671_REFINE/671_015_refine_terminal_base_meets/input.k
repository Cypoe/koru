// Test: a terminal-typed field refines — `port: Port` where Port minted by
// `std/proto:i64(Port)` takes bounds spelled against the terminal name, not
// the host scalar. The base check resolves Port → i64; the guard enforces
// on the name (`port > 1024` compiles because `Port` is `i64`).
//
// Expected: runs clean — `rejected port` then `len=1` (expected.txt).
import std/proto
import std/refine
import std/list
import std/io

std/proto:i64(Port)

std/proto(Server) {
    port: Port,
    host: string
}

std/refine(Server) {
    port: Port & >1024 & <=65535
    host: string
}

std/list:new(Server)
| list xs |> std/list:push(xs, port: 80, host: "web-01")
    | ok |> std/io:print.ln("unexpected accept") |> std/list:free(xs)
    | violated f |> std/io:print.ln("rejected {{ f:s }}") |> std/list:push(xs, port: 8080, host: "web-01") |> std/list:len(xs): n |> std/io:print.ln("len={{ n:d }}") |> std/list:free(xs)
| err e |> std/io:print.ln("ERR {{ e:s }}")
