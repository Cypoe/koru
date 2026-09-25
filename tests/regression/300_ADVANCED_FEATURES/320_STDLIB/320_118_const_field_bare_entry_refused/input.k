// PINS: a bare name in a `const { }` block — `x` with no `: value` — is
// refused KORU176. Const has no pun: nothing at container scope exists to
// bind the name from, so the entry would silently declare nothing.
import std/io

const {
    a: @as(i32, 5), x
}

std/io:print.ln("unreachable")
