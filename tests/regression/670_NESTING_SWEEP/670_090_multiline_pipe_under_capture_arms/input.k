// NESTING SWEEP — a MULTI-LINE `|>` chain inside a capture's `! as`
// accumulator arm, under BOTH sibling wrappers the corpus spells for a
// capture: the anonymous flow-head form (`capture {…}` as a bare item) and
// the named-subflow form (`tor bump {} -> i64` + `bump = capture {…}`).
//
// Grounds: the `! as acc |> captured {…}` / `| captured r` arm shape
// (670_010, and 660_023 for an INLINE `|>` chain in `! as`); the `=`
// subflow wrap of a capture with `| captured r -> r.field` produce
// (810_211); the equal-indent multi-line `|>` continuation (220_020 at flow
// head, 220_017 under a watch `!` arm, 220_024 under an obligation `|` arm —
// none inside `! as`). The `! as` arm is an effect arm; its body must
// behave like every other effect-arm body — a `|>` chain is one body
// whether written inline or across equal-indent continuation lines, and
// whether the enclosing capture is anonymous or named.
//
// Both forms fold 0 → +1 → +2 → +4 = 7. The anonymous capture runs at its
// top-level position; the named subflow runs when `bump()` is invoked.
import std/io

capture { n: 0[i64] }
! as acc |> captured { n: acc.n + 1 }
    |> captured { n: acc.n + 2 }
    |> captured { n: acc.n + 4 }
| captured r |> std/io:print.ln("anon n={{ r.n:d }}")

tor bump {} -> i64
bump = capture { n: 0[i64] }
! as acc |> captured { n: acc.n + 1 }
    |> captured { n: acc.n + 2 }
    |> captured { n: acc.n + 4 }
| captured r -> r.n

bump(): v |> std/io:print.ln("named n={{ v:d }}")
