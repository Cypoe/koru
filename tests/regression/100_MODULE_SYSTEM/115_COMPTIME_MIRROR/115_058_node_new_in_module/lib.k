import std/io
import std/node
import std/cell
import std/proto
import std/runtime

std/proto(room_state) {
    visits: u32
}

pub tor greet { name: string } -> string
greet -> name

std/runtime:register(scope: "cell") {
    greet(5)
}

pub tor run {}

// Worldless node, same as 450_001: the harness runs output binaries with
// cwd = repo root, so a world root would litter it.
run = std/node:new(node, scope: "cell", world: "", capacity: 8)
|> std/io:print.ln("node up")
|> std/node(node)
| node f |> std/node:drain(f): n |> std/io:print.ln("drained {{ n:d }} cell(s)")
