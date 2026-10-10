// PINS: inside a `name =` flow body, an own-line `|> if(cond)` step takes its
// `| then` / `| else` arms on the following lines — the same attachment the
// keyword tor gets inside `!` arm bodies (210_314) and at a bare flow head
// (040_CONTROL_FLOW/241). Dispatch-arm attachment on `|>` tor-call steps in
// `=` bodies is unaffected; the hole was `if`-specific arm collection in the
// flow-decl chain.

import std/io

pub tor step { x: i64 }
step = std/io:print.ln("step {{ x:d }}")

main =
    step(x: 1)
    |> if(true)
        | then |> std/io:print.ln("then")
        | else |> std/io:print.ln("else")
