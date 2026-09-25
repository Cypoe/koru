// PINS: an insert value ending in an index `xs[0]` fused with the next field
// refuses KORU161 naming the missing comma — not a wrong-arity complaint.
// `xs[0]` is indexing (a `]`-closed value tail), not a `[`-led type prefix.
import std/io
import std/store

std/store:new(ents, capacity: 4) { px: i64, py: i64 }

std/store:insert(ents) { px: xs[0] py: 1 }

std/io:print.ln("unreachable")
