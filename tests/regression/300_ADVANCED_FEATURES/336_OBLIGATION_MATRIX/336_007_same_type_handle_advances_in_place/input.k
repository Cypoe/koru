// IMPLEMENTED — a same-typed transition CONTINUES its binding.
//
// `advance` consumes `h` (<!open|!active>) and re-mints <active!> on the same
// handle: `-> h` IS the transition written out. The entity is `h` throughout.
// Today the caller must spend `h` and re-bind the re-minted handle under a new
// name (`app/held:advance(h): h2 |> close(h2)`), which carries no information —
// the new symbol is the old pointer with a new state. The intended rule: the
// sole same-typed survivor advances `h` in place, so `close` just uses `h`.
//
// Green: the `desugarHandleContinuation` pass rewrites `advance(h)` into the
// explicit `: __cont0` bind and points `close` at it (see output_emitted.zig).
import app/held
import std/io

app/held:open()
| opened h |> app/held:advance(h) |> app/held:close(h) |> std/io:print.ln("advanced in place")
| err e |> std/io:print.ln("err: {{ e:s }}")
