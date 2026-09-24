// PIN: a file declares each tor once. 140_024 enforces the same rule across
// the part boundary (KORU202); inside one file a second `tor greet` is a
// redeclaration, not an overload — the caret lands on the redeclaring head.

import std/io

tor greet { name: string } -> string
tor greet { count: i64 } -> i64

greet -> "hi"

greet (name: "World"): msg |> std/io:print.ln(msg)
