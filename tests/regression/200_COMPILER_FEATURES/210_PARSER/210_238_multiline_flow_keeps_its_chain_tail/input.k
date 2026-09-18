// PIN — a `|>` chain at TOP-LEVEL flow position written across two lines
// keeps every step. Measured 2026-09-18: it refuses, reporting
// KORU100 'unused binding m' — TRUE of the tree the parser built and
// false of the program the author wrote: `m` is used in the very next
// step. The trailing `|>` never reaches the next line.
//
// Twin of 210_200, which pinned the same drop inside `=` subflow bodies
// and cites the invariant at parser.zig:6114 — "multi-line pipe chain
// parses EXACTLY like its inline spelling. ONE rule for `|>` chains
// everywhere." The fix covered `=` bodies; top-level flow position
// still parses only the head.
import std/io

tor mail {} -> string
mail -> "hello"

mail(): m |>
std/io:print.ln("got: {{ m:s }}")
