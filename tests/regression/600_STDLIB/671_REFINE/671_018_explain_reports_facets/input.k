// Test: `koruc explain` on a refined proto — std/refine's explainer folds
// contributor blocks through the same meet machinery the transform runs
// (declared base, resolved terminal scalar, per-field effect); std/list's
// explainer reports what push enforces on the element's facet. post.sh
// drives both formats.
import std/proto
import std/refine
import std/list
import std/io
import std/explain

std/proto:i64(Port)

std/proto(Server) {
    port: Port,
    gain: i64,
    host: string
}

std/refine(Server) {
    port: Port & >1024 & <=65535
    gain: i64 & clamp(0, 100)
    host: string
}

std/list:new(Server)
| list xs |> std/list:push(xs, port: 8080, gain: 42, host: "web-01")
    | ok |> std/list:len(xs): n |> std/io:print.ln("len={{ n:d }}") |> std/list:free(xs)
    | violated f |> std/io:print.ln("refused")
| err e |> std/io:print.ln("ERR")
