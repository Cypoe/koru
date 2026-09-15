// Test: refine enforcement rides a panic branch — std/list:push declares
// `| ?!violated string`; the guard produces into it (`port: 80` violates
// `port: i64 & >1024`) instead of trapping inline.
//
// Expected: the call site handles no panic branches, so `?!violated` gets the
//           synthesized arm — stderr echoes the payload (the field name) and
//           the process traps (EXPECT_TRAP, expected_patterns).
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
| list xs |> std/list:push(xs, port: 80, host: "web-01") |> std/io:print.ln("never")
| err e |> std/io:print.ln("ERR {{ e:s }}")
