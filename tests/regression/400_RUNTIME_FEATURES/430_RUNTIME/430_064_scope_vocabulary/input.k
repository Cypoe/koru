// Test: std/runtime:scope-vocabulary renders a scope's vocabulary from the
// register block — the surface that lets a running program tell a model what
// it may call, derived from the declaration instead of a hand-typed prompt.
// The prompt and the enforcement are the same bytes: the possession phantoms
// rendered here are the ones the interpreter checks before dispatch, and the
// outcome contracts are the branches the arm spelling must name.
//
// Pure-surface form (.k): the tilde does not exist here — a pure-Koru file
// rejects it outright (PARSE003), which is exactly the point of the spelling.
import std/runtime
import std/io
import std/void

pub tor open { path: string } -> string<open!>
open -> "note_0"

pub tor append { handle: string<!open>, text: string } -> string<open!>
append -> handle

pub tor close { handle: string<!open> }
close = std/void:placeholder()

pub tor say { text: string }
say = std/void:placeholder()

// A branchful verb: the vocabulary line carries its outcome contract —
// required branches bare, the optional one `?`-marked — because an arm
// can only name a branch the prompt shows.
pub tor read { path: string }
| ok string
| missing string
| too-large string
| ?hint string
proc read|zig {
    _ = path;
    return .{ .ok = "contents" };
}

std/runtime:register(scope: "notes") {
    open(10)
    append(1)
    close(1)
    say(1)
    read(1)
}

std/runtime:scope-vocabulary(name: "notes")
| ok vocab |> std/io:print.ln("{{ vocab:s }}")
| not-found |> std/io:print.ln("NOT FOUND")

std/runtime:scope-vocabulary(name: "no-such-scope")
| ok vocab |> std/io:print.ln("UNEXPECTED: {{ vocab:s }}")
| not-found |> std/io:print.ln("NOT FOUND")