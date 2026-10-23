// Comptime-mirror fields ride a placeholder: `expr: Expression` is the
// compiler's own AST type — unobservable in C by construction — so the
// field cell is a nominal one-byte hole and the call-site arg emits `{0}`.
// The neighboring `tag` field is a real value and must read identically.
import std/io

tor echo { expr: Expression, tag: i64 } -> i64
echo -> tag

echo(expr: 1 + 2, tag: 7): r |> std/io:print.ln("tag: {{ r:d }}")
echo(expr: "text", tag: 9): r |> std/io:print.ln("tag: {{ r:d }}")
