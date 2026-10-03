// The bug: a string literal flows into an i64 parameter.
// The honest wound cell: today this escapes the frontend and is refused by
// the Zig backend on output_emitted.zig coordinates, not type_mismatch/koru.k.
// If a future run reports a source-mapped KORU diagnostic, the gap is fixed.

import std/io

pub tor take { x: i64 } -> i64
take -> x

take(x: "hello"): r |> std/io:print.ln("{{ r:d }}")
