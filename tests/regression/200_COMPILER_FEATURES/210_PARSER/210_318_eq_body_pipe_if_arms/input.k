// PINS: inside a `name =` flow body, an own-line `|> if(cond)` step takes its
// `| then` / `| else` arms on the following lines — the same attachment the
// keyword tor gets inside `!` arm bodies (210_314) and at a bare flow head
// (040_CONTROL_FLOW/241). Nested-arm collection under `|>` steps in `=` bodies
// covers keyword dispatches generally (`|> for` + `! each` refused identically);
// dispatch arms at the step's own level were never affected.

import std/io

pub tor step { x: i64 }
step = std/io:print.ln("step {{ x:d }}")

pub tor worker {}
worker =
    step(x: 1)
    |> if(true)
        | then |> std/io:print.ln("then")
        | else |> std/io:print.ln("else")

worker()
