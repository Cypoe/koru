// A malformed [size(...)] cannot refuse through SiteResult (no error
// channel) — the transform emits @compileError into the generated source:
// still compile-time, still teaching, never a silent default.
import std/fmt
import std/io

pub tor big { s: string }
big = std/io:print.ln("warm")
    |> [size(xyz)]std/fmt:ln("{{ s:s }}"): l
    |> std/io:print.ln(l.text)

big(s: "ssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss")
