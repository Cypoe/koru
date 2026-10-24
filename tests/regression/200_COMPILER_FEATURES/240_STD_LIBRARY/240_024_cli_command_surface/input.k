// Test (ASPIRATIONAL, MUST_RUN, currently failing): the std/cli command
// surface — commander-shaped argv dispatch synthesized from declarations.
//
//   std/cli:flag(name) { "type": ..., "short": ..., "description": ... }
//   std/cli:command(name) { "description": ..., "subcommands": [...] }
//
// are [comptime|norun] Source-record declarations — the compiler.kz
// flag.declare/command.declare idiom, positional name + block body.
// `std/cli()` resolves to the module's `default` transform tor
// (import_pipeline rewrites bare mod() to ["default"]; channel.kz:919 is
// the precedent), which harvests the declares from the program AST and
// the command arms from its own continuations, and emits argv parse +
// generated --help + dispatch — the std/json:parse emit pattern.
//
// The destructure is the arm's argument grammar — the tor attached to the
// branch owns its meaning (the json:parse license): a typed field
// (`file: string`) is a positional converted at the splice; a field
// matching a declared flag (`verbose`) binds the parsed flag; `subcommand`
// binds argv-after-command, constrained against the declare's
// "subcommands" list. `| usage` and `| help` are optional arms with a
// generated print+exit default. A `| build` arm with no matching declare
// still dispatches — declares carry prose, arms carry shape.
//
// Program name/version for the usage line are harvested from
// std/build:app when present (identity lives there, not here) and fall
// back to the entry-file stem.
//
// ARGS = "run\ncheck\nmyfile.txt\n--verbose" →
//   argv = [program, run, check, myfile.txt, --verbose].

import std/cli
import std/io

std/cli:flag(verbose) {
    "type": "boolean",
    "short": "v",
    "description": "chatter"
}

std/cli:flag(output) {
    "type": "string",
    "required": true,
    "description": "write here"
}

std/cli:command(run) {
    "description": "run the thing",
    "subcommands": ["check", "fire"]
}

std/cli()
| run { subcommand, file: string, verbose } |> std/io:print.ln("run {{ subcommand:s }} {{ file:s }} v={{ verbose:any }}")
| build |> std/io:print.ln("build")
| usage { message } |> std/io:print.ln("usage: {{ message:s }}")
| help text |> std/io:print.ln("{{ text:s }}")
