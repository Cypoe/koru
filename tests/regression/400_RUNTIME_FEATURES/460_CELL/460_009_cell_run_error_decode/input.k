// Test: `std/cell:error-decode` — the fine-grained arm set behind `| error`.
//
// `run` is re-tiered to two required arms — `| result` and `| error` — with
// every failure class folded into the RunError record (`kind` names the
// variant). A caller that distinguishes classes sends `e` through
// `error-decode`: each optional arm fires for exactly one kind, carrying
// that variant's typed payload — `p.line`/`p.column` land on parse-error,
// not on a stringly re-parse.

import std/io
import std/cell
import std/proto
import std/runtime

std/proto(room_state) {
    visits: u32
}

pub tor greet { name: string } -> string
greet -> "hello {{ name:s }}"

std/runtime:register(scope: "cell") {
    greet(5)
}

std/cell:open(room_state, id: "assistant")
| cell c |> std/cell:run(c, source: "greet(name:")
    | result _ |> std/io:print.ln("unexpected result")
    | error e |> std/io:print.ln("kind={{ e.kind:s }}")
      |> std/cell:error-decode(e)
        | parse-error p |> std/io:print.ln("decoded parse-error {{ p.line:d }}:{{ p.column:d }} msg={{ p.message:s }}")
        | event-denied d |> std/io:print.ln("decoded denied {{ d:s }}")
  |> std/cell:run(c, source: "nosuch()")
    | result _ |> std/io:print.ln("unexpected result 2")
    | error e2 |> std/io:print.ln("kind2={{ e2.kind:s }}")
      |> std/cell:error-decode(e: e2)
        | event-denied d2 |> std/io:print.ln("decoded denied: {{ d2:s }}")
        | dispatch-error d3 |> std/io:print.ln("decoded dispatch: {{ d3.event_name:s }}")
        | unknown-error ux |> std/io:print.ln("decoded unknown: {{ ux.kind:s }}")
  |> std/cell:hibernate(c)
