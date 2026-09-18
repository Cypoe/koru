// PIN — a `|>` at end-of-line with nothing after it is a dangling operator,
// refused everywhere: the handler body follows `|>` on the SAME line, and the
// multi-line chain form leads with `|>` on the next line instead (210_208 pins
// that form at this same top-level position).
//
// Branch position already enforces this — `| ok x |>` + body-below is
// PARSE001 "must follow '|>' on the same line" (210_066). A flow-head chain
// head carries the same operator; the same refusal applies.
import std/io

tor mail {} -> string
mail -> "hello"

mail(): m |>
std/io:print.ln("got: {{ m:s }}")
