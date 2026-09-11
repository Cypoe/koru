// IMPLEMENTED — the BRANCH-payload twin of 336_007.
//
// `advance` re-mints <active!> on the same handle through a named payload field
// `h`, matching the input field `h` — the `window.paint { win } | painted { win }`
// shape. Because the field names coincide, the output is the SAME entity
// advanced, so `h` should continue and `close` should use `h` directly. Today
// the caller must spend `h` and re-bind (`| advanced p |> close(p.h)`).
//
// Green: the identity payload `| advanced *Handle<active!> |` continues `h`;
// the arm binds `__cont0` and `close` uses it (output_emitted.zig).
import app/held
import std/io

app/held:open()
| opened h |> app/held:advance(h, n: 1)
    | advanced _ |> app/held:close(h)
    | err e |> std/io:print.ln("advance err: {{ e:s }}")
| err e |> std/io:print.ln("err: {{ e:s }}")
