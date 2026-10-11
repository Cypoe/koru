// PINS the G-CC-1 canonical cell — the finite byte transducer class.
// Pure computation, no `!` arms, no host lines: `transduce` concatenates
// fixed strings around its input and `print.ln` writes the bytes.
// Under --lang=c the emitted C must build under the ccomp oracle and
// reproduce stdout byte-for-byte — the same expected.txt the Zig lane
// satisfies (regression_check_c_equivalence).
import std/io

tor transduce { input: string } -> string

transduce -> "prefix: " ++ input ++ " :suffix"

transduce (input: "hello"): out |> std/io:print.ln(out)
