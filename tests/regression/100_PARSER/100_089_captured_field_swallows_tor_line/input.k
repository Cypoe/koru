// PINS: a tor line inside a `captured { }` field body is REFUSED — the
//       field-value scanner may not swallow a following `!` / `|>` line as
//       expression continuation. Sibling of 100_083 (unclosed paren in a
//       capture value): same silent-absorption failure mode, different door —
//       this one is a tor line, not a stray bracket.
//
// Found by the composition GP fuzzer: a spliced `! row` subtree inside
// `captured {}` compiled green under --deep-check while the emitted Zig
// carried the Koru line verbatim — `acc.n = acc.n + 1\n! bogus e |> ...` —
// which is not parseable Zig. `zig ast-check` fails on the emission; the
// "pass" was a frontend that accepted what it never checked.
import std/io
import std/fs

capture { n: 0[i64] }
! as acc |> std/fs:read-lines(path: "nonexistent.txt")
    ! line _ |> captured {
        n: acc.n + 1
        ! bogus e |> std/io:print.ln("x")
    }
| captured total |> std/io:print.ln("{{ total.n:d }}")
