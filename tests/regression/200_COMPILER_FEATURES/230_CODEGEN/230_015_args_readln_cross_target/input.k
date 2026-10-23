// argv and one stdin line cross both lanes. ARGS feeds argv[1..];
// STDIN feeds std/io:readln's single blocking line read.
import std/args
import std/io

std/args:count(): n |> std/io:print.ln("count: {{ n:d }}")

std/args:get(index: 1)
| arg a |> std/io:print.ln("a1: {{ a:s }}")
| out-of-bounds |> std/io:print.ln("a1: <none>")

std/args:get(index: 9)
| arg a |> std/io:print.ln("a9: {{ a:s }}")
| out-of-bounds |> std/io:print.ln("a9: <none>")

std/io:readln()
| line s |> std/io:print.ln("line: {{ s:s }}")
| eof |> std/io:print.ln("eof")
| failed e |> std/io:print.ln("FAILED: {{ e:s }}")
