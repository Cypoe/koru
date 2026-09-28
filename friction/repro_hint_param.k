import std/io

tor mm-of { kind: i32, a: i32, b: i32 } -> i32
mm-of -> if (kind == 0) a else b

use = mm-of(1, 2, 3): m
    |> std/io:print.ln("{{ m:d }}")
