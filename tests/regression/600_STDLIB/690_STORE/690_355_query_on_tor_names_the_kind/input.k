// PINS: `query(name)` on a declared TOR must name what the name actually is.
// The old miss said "unknown plural store" for every non-store name, which
// taught the agent the name was wrong when the spelling was — a tor is
// called, not swept. KORU161's dominant sub-family (~30 corpus rows) was
// exactly this: query() aimed at a name that exists but isn't a container.
import std/io
import std/store

tor phase { } -> i32
phase -> 1

std/store:query(phase)
! query p |> std/io:print.ln("{{ p:d }}")
