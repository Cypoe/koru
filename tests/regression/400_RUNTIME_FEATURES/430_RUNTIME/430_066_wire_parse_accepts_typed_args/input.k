// Pins the wire grammar's typed side: `std/runtime:parse.wire` accepts bare
// literal values — ints, floats, bools — the same forms `parse.source` +
// `eval` dispatch with full types (430_041). The wire is the agent-facing
// shape-check over the same invocation grammar; a value the evaluator can
// type is a value the wire accepts. Quoted strings stay legal — bare values
// join them instead of being refused at the shape check.
import std/runtime
import std/io

pub tor set-config { enabled: bool, ratio: f64, count: i64 } -> string
set-config -> "ok"

std/runtime:register(scope: "api") {
    set-config(1)
}

std/runtime:parse.wire(source: "set-config(enabled: true, ratio: 3.5, count: 42)")
| parsed _ |> std/io:print.ln("PARSED TYPED")
| parse-error e |> std/io:print.ln("UNEXPECTED: {{ e.message:s }}")

std/runtime:parse.wire(source: "set-config(enabled: false, ratio: -0.25, count: -7)")
| parsed _ |> std/io:print.ln("PARSED NEGATIVE")
| parse-error e |> std/io:print.ln("UNEXPECTED: {{ e.message:s }}")

std/runtime:parse.wire(source: "set-config(enabled: \"true\", ratio: \"3.5\", count: \"42\")")
| parsed _ |> std/io:print.ln("PARSED QUOTED")
| parse-error e |> std/io:print.ln("UNEXPECTED: {{ e.message:s }}")
