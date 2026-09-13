// A `~if` template consumes only its `| then` arm via `__koru_continue_N`;
// the `|>` steps written AFTER the if are the caller's chain sequel, not the
// template's arms. The JS emitter's unconsumed-continuation drain must emit
// them body-only (no tagged result exists at a dispatcher site) while still
// skipping the template's own unmarked named arms — a synthesized `| done`
// no-op on the enclosing `~for` carries an auto-discharge `_auto_N` binding
// and must NOT be drained as if it were a sequel.
import std/io

for(0..1)
! each a |> std/io:print.ln("before")
    |> if(a == 0)
        | then |> std/io:print.ln("in-then")
    |> std/io:print.ln("after-if")
