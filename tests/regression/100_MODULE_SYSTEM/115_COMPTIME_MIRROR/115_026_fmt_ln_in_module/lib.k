import std/fmt
import std/io

pub tor greet { name: string }

greet = std/fmt:ln("Hello, {{ name:s }}!"): l |> std/io:print.ln(l.text)
