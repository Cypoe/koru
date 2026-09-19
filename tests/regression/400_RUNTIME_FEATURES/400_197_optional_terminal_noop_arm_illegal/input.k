// An OPTIONAL terminal branch armed with a bare `_` discard is illegal.
// `for` declares `| ?done` — omitting the arm already discards it, so an
// explicit `| done |> _` is pure noise that misreads as "required, consciously
// ignored" and would silently swallow the event if the branch were later
// promoted to REQUIRED. Omit it, or give it a real body.
import std/io
import std/control

for(0..3)
! each i |> std/io:print.ln("{{ i:d }}")
| done |> _
