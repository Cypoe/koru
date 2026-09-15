// Test: the refine violation is supervisable — `port: 80` fires push's
// `?!violated` branch carrying the field name, and the caller HANDLES it
// (`| violated f |>`) instead of leaving the synthesized @panic. The flow
// survives, pushes a valid record, and reports len=1.
//
// Expected: runs clean — `rejected port` then `len=1` (expected.txt). The
//           `?!oom` arm is left unhandled: synthesized @panic, never reached.
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
| list xs |> std/list:push(xs, port: 80, host: "web-01")
    | ok |> std/io:print.ln("unexpected accept") |> std/list:free(xs)
    | violated f |> std/io:print.ln("rejected {{ f:s }}") |> std/list:push(xs, port: 8080, host: "web-01") |> std/list:len(xs): n |> std/io:print.ln("len={{ n:d }}") |> std/list:free(xs)
| err e |> std/io:print.ln("ERR {{ e:s }}")
