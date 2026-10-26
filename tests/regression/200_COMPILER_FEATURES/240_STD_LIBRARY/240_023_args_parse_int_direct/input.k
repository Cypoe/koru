// Test: argv feeds parse-int directly — `arg` is `[:0]u8`, and
// parse-int's `s: string<*>` accepts it without a from-page round-trip.
// ARGS = "41\nbad" → argv = [program, 41, bad]; plus the owned-String
// path stays pinned (h.data projection).
import std/args
import std/string
import std/io

std/args:get(index: 1)
| arg a |> std/string:parse-int(s: a)
    | ok n |> std/io:print.ln("ok: {{ n:d }}")
    | err _ |> std/io:print.ln("err")
| out-of-bounds |> std/io:print.ln("oob")

std/args:get(index: 2)
| arg a |> std/string:parse-int(s: a)
    | ok n |> std/io:print.ln("ok: {{ n:d }}")
    | err _ |> std/io:print.ln("err")
| out-of-bounds |> std/io:print.ln("oob")

std/string:from-page(text: "7")
| ok h |> std/string:parse-int(s: h.data)
    | ok n |> std/io:print.ln("str: {{ n:d }}")
        |> std/string:free(s: h): _
    | err _ |> std/io:print.ln("str err")
| err _ |> _
