// Test: the first enforcing consumer — std/list:push reads the element's
// facet_decl and synthesizes a bounds check into push-<Name>'s body.
// `port: 80` violates `port: i64 & >1024` — the synthesized guard panics
// before the append.
//
// Expected: the process traps (EXPECT_TRAP); stderr carries the panic line
//           naming the type and field (expected_patterns).
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
