// PINS: a `const { }` entry fused onto the previous field's line for want of
// a comma — `a: @as(i32, 5) b: @as(i32, 2)` — is refused KORU176 naming the
// fused field, under the same missing-comma rule every other field list is
// held to. The caret lands on the line carrying the fused pair.
import std/io

const {
    a: @as(i32, 5) b: @as(i32, 2)
}

std/io:print.ln("unreachable")
