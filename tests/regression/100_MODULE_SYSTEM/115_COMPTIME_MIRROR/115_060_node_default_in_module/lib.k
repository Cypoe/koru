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

// The bare borrow, spelled two ways — each at the head of its own flow,
// which is the position std/node:default rules on.
pub tor borrow-node {}
borrow-node = std/node(node)
| node f |> std/io:print.ln("node borrowed")

pub tor borrow-member {}
borrow-member = std/node(node.absent-9)
| cell c |> std/io:print.ln("unexpected cell")
| held-by o |> std/io:print.ln("held by {{ o:s }}")
| not-found |> std/io:print.ln("absent-9 not found")

pub tor run {}

run = std/node:new(node, scope: "cell", world: "", capacity: 8)
|> borrow-node()
|> borrow-member()
|> std/node(node)
| node f |> std/node:drain(f): n |> std/io:print.ln("drained {{ n:d }} cell(s)")
