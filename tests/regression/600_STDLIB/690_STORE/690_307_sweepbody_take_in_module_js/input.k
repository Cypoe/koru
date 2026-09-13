import std/io
import world

world:seed() |> world:collect() |> std/io:print.ln("done")
