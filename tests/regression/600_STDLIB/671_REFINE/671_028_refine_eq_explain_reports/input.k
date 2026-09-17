// Test: `koruc explain` reports an equality atom like any other term —
// the met facet spells `==8080`, the field's effect is `refuse` (the
// boundary rejects what the equality excludes), and std/list reports the
// same field as enforced. post.sh drives the text rows and the typed json.
import std/proto
import std/refine
import std/list
import std/io
import std/explain

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
    | ok |> std/list:len(xs): n |> std/io:print.ln("len={{ n:d }}") |> std/list:free(xs)
    | violated f |> std/io:print.ln("refused")
| err e |> std/io:print.ln("ERR")
