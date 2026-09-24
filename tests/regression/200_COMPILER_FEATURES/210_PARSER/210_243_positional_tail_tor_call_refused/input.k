// PINS: the law is call-level, not std-level — an ordinary tor invocation
// must refuse a bare literal tail too. `mk(a: 41, 37)`: the named arg is
// legal; the 37 cannot pun.
import std/io

tor mk { a: i64 } -> i64
mk = a

mk(a: 41, 37): v |> std/io:print.ln("{{ v:d }}")
