// Pins: optional branches inside an event body (subflow) absorb silently
// when unnamed — same rule as top-level dispatches. Gallery on-q: text
// pages keep; `catalog`/`style` go unnamed and the body does nothing.
import std/io

tor page-route { page: i64 }
| ?catalog
| ?text-input
| ?style

page-route = if(page == 0)
| then => catalog
| else |> if(page == 1)
    | then => text-input
    | else => style

tor on-q { page: i64 }
on-q = page-route(page)
| text-input |> std/io:print.ln("keep")

on-q(page: 0)
on-q(page: 1)
on-q(page: 2)
