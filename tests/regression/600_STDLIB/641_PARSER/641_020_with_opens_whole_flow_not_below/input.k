// PINS the extent ruling: `[with]` is a property of the WHOLE flow, not a
// scope that opens below the tag. resolve-with-scopes gathers every `[with]`
// in a flow body, then resolves that same body — so the bare `ping` head here
// resolves through an opener that sits LATER in the chain. Position is
// cosmetic; the open set belongs to the flow.
import std/io
import app/alpha

ping(msg: "seed"): s |> [with]app/alpha:ping(msg: s): t |> std/io:print.ln("resolved={{ t:s }}")
