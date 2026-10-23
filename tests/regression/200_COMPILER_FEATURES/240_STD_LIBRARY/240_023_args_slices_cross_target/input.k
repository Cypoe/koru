// Fat-slice cross-target: std/args' `[][:0]u8` returns ride a {ptr, len}
// cell — `.len` reads the member, `r[i]` indexes through `.ptr`, and a
// slice element's own `.len` is the thin string cell's strlen. Pin: the
// same input produces identical output on the zig and C oracle lanes.
import std/args
import std/io

std/args:all(): a |> std/io:print.ln("all: {{ a.len:d }}")
std/args:rest(): r |> std/io:print.ln("rest: {{ r.len:d }}")
std/args:rest(): r2 |> std/io:print.ln("first: {{ r2[0]:s }}")
std/args:rest(): r3 |> std/io:print.ln("second: {{ r3[1]:s }}")
std/args:rest(): r4 |> std/io:print.ln("first-len: {{ r4[0].len:d }}")
