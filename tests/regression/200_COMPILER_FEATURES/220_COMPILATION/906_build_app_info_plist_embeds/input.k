import app/test_lib/selfread
import std/build
import std/io

std/build:app { name: "Regtest App", id: "org.koru.regtest", version: "0.1" }

app/test_lib/selfread:id()
| id s |> std/io:print.ln("embedded: {{ s:s }}")
| none |> std/io:print.ln("missing")
