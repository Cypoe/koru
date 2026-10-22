import std/io
import std/cell
import std/proto
import std/runtime
import std/interpreter

std/proto(room_state) {
    visits: u32
}

pub tor greet { name: string } -> string
greet -> name

std/runtime:register(scope: "cell") {
    greet(5)
}

pub tor run {}

run = std/cell:open(room_state, id: "assistant")
| cell c |> std/cell:run(c, source: "greet(name: \"assistant\")")
  | result r |> std/interpreter:value.stringify(r.value): j |> std/io:print.ln("cell said: {{ j:s }}")
  | error e |> std/io:print.ln("turn failed: {{ e.kind:s }}")
  |> std/cell:hibernate(c) |> std/io:print.ln("assistant hibernated")
