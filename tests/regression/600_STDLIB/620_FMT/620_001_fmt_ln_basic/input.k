// TEST: fmt:ln basic — format a string and bind the result with `: l`.
// `.text` is a scoped borrow (scratch@scoped) — consume it in place.
import std/fmt
import std/io

tor greet { name: string }

greet = std/fmt:ln("Hello, {{ name:s }}!"): l |> std/io:print.ln(l.text)

greet(name: "World")
