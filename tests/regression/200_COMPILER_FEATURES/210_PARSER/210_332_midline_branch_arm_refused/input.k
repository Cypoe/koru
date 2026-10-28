// PIN — a `| name` branch arm written MID-LINE is refused, not silently
// dropped.
//
// THE SHAPE: `| then |> if (k) | then |> step` — the second `| then`
// continues the line inside the outer then-arm's body. Branch arms open on
// their own line; mid-line the arm has no legal construct to dispatch on.
//
// WHAT IT DID BEFORE: parseEventInvocation truncated the invocation head at
// the first top-level `|` and dropped the arm silently — the inner `if`
// emitted `if (k) {} else {}` (a required-`then` with an EMPTY true arm) and
// the step ran unconditionally. oshun's field_cam.k hit this: every kind
// label drew on every card.
//
// LEGAL NEIGHBOURS kept open: `| name` after `->`/`=>` belongs to the
// produce tail (event taps, 420_008), and `| name` directly after `}` arms
// the closed block invocation (`fmt.blk { … } | formatted`, 390_004).
import std/io

pub tor start {} -> { }

start = std/io:print.ln("start")
    |> if (true)
        | then |> if (false) | then |> std/io:print.ln("WRONG")
    |> std/io:print.ln("done")
