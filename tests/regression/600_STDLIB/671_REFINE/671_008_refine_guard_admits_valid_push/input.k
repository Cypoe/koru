// Test: the synthesized bounds guard admits in-bounds pushes — the check
// fires only on violation. `v: 8080` meets `port: i64 & >1024 & <=65535`,
// the append runs, and len reports the element landed.
//
// Expected: runs clean — prints `len=1` (expected.txt).
import std/proto
import std/refine
import std/list
import std/io

std/proto(Server) {
    port: i64
    host: string
}

std/refine(Server) {
    port: i64 & >1024 & <=65535
    host: string
}

std/list:new(Server)
| list xs |> std/list:push(xs, v: 8080) |> std/list:len(xs): n |> std/io:print.ln("len={{ n:d }}") |> std/list:free(xs)
| err e |> std/io:print.ln("ERR {{ e:s }}")
