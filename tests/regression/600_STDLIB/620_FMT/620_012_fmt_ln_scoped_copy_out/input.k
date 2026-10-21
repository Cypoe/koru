// TEST: fmt:ln scoped borrow — copy-out through std/string is the LEGAL
// escape (the negative twin is 620_011's refused `-> l.text`). `.text`
// carries scratch@scoped — frame-bound, unread at produce — so the owned
// bytes go through from-page + take; the produced value is a plain owned
// String that leaves the frame lawfully.
import std/fmt
import std/io
import std/string
import std/panic

tor greet { name: string } -> *std/string:String<instance!>

greet = std/fmt:ln("Hello, {{ name:s }}!"): l
    |> std/string:from-page(l.text)
    | ok s |> std/string:take(s): owned -> owned
    | err _ |> std/panic:die(msg: "alloc")

greet(name: "World"): g |> std/io:print.ln(g.data) |> std/string:free(s: g)
