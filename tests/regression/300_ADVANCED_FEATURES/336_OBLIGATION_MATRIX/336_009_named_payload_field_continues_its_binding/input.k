// ASPIRATIONAL — a NAMED payload field continues its same-named input binding.
//
// The output is a multi-field record; its `h` field names the same entity as
// the input `h`, so `h` should advance in place and `close` should use `h`.
// The other payload field (`n`) is an ordinary new binding. Today the caller
// must spend `h` and reach the handle back through the payload record `p.h`.
//
// Red today (KORU030: `h` is spent at the `advance` call); green when a
// name-matched payload field scores the re-mint onto the input binding.
import app/held
import std/io

app/held:open()
| opened h |> app/held:advance(h, n: 1)
    | advanced p |> std/io:print.ln("advanced, n={{ p.n:d }}") |> app/held:close(h)
    | err e |> std/io:print.ln("advance err: {{ e:s }}")
| err e |> std/io:print.ln("err: {{ e:s }}")
