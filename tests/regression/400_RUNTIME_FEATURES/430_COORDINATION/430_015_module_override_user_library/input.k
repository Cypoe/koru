import std/io
import app/lib/greet
import app/discount

app/lib/greet:greet(name: "world")
| greeted g |> std/io:print.ln("{{ g:s }}")
| skipped |> std/io:print.ln("skipped")
