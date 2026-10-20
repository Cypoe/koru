// [size(64)] tightens the scratch: 500 output bytes panic, and the panic
// names the site's configured size — the annotation is live, not advisory.
import std/fmt
import std/io

pub tor big { s: string }
big = std/io:print.ln("warm")
    |> [size(64)]std/fmt:ln("{{ s:s }}"): l
    |> std/io:print.ln(l.text)

big(s: "ssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss")
