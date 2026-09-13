import std/io
import world

world:push(vx: 0.5): v |> std/io:print.ln("pushed {{ v:d:.4 }}")
