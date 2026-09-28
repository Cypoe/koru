// Pins the wire grammar's string discipline: a value that opens with a
// double quote must close with one. An unterminated string is a truncated
// model reply — the refusal says so, rather than letting a partial line
// dispatch with a silently shortened argument. An unquoted bare token is
// legal shape (a bound name or literal, 430_066) — `greet(name: kopium)`
// parses the gate and is refused downstream as an unbound name.
import std/runtime
import std/io

pub tor greet { name: string } -> string
greet -> name

std/runtime:register(scope: "api") {
    greet(1)
}

std/runtime:parse.wire(source: "greet(name: \"kopium)")
| parsed f |> std/io:print.ln("UNEXPECTED PARSED")
| parse-error e |> std/io:print.ln("PARSE ERROR UNTERMINATED")

std/runtime:parse.wire(source: "greet(name: kopium)")
| parsed f |> std/io:print.ln("UNEXPECTED PARSED")
| parse-error e |> std/io:print.ln("PARSE ERROR UNQUOTED")
