// MIRROR of 620_001_fmt_ln_basic: a tor implemented by `std/fmt:ln`, relocated
// into an imported module. `.text` is consumed in place — a scoped borrow
// cannot cross the module boundary through a bare return.
import std/io
import app/lib

app/lib:greet(name: "World")
