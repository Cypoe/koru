// PINS the refusal of `[ann]` after `=` in a subflow impl. Today the bracket
// text falls into the head path and the callee compiles to a tor literally
// named '[with]app.alpha:ping' — a Stage-A annotation leaking into a name,
// reported three stages later as an unknown tor. The annotation position that
// parses is BEFORE the impl name: `[with]start = ...`. Refuse the `=`-position
// spelling at parse with that teaching instead of mangling the callee.
import std/io
import app/alpha

tor start {}
start = [with]app/alpha:ping(msg: "x"): s |> std/io:print.ln("{{ s:s }}")

start()
