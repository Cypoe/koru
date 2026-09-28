// Pins: the code register generates — dispatcher helpers, per-event dispatch
// fns, dispatch_<scope>, scope lookup tables — lives in the __koru_* name
// space, so module state named after any generated binding still compiles
// and runs. app/state.kz declares a decl for every name the generator once
// emitted bare into the module's own namespace, where `var name_len`
// shadow-collided with the generated dispatcher local and killed the build.
//
// (kopium wired hole 8 — headless/ledger.kz declared `var name_len`.)
import std/io
import std/bridge
import app/state

// One turn: dispatch must still reach ping — which writes and prints the
// module's own name_len, the decl the generated local once shadowed.
tor ping-turn { br: *std/bridge:Bridge }
ping-turn = std/bridge:run(br, source: "ping(text: \"hi\")")
| result res |> std/io:print.ln("after ping, holds {{ res.handles:d }}")
| unhandled-branch ub |> std/io:print.ln("FAIL unhandled {{ ub.branch:s }}")
| event-denied ev2 |> std/io:print.ln("FAIL denied {{ ev2:s }}")
| residue _ |> std/io:print.ln("FAIL: residue outcome")
| parse-error pe |> std/io:print.ln("FAIL parse {{ pe.message:s }}")
| validation-error ve |> std/io:print.ln("FAIL invalid {{ ve:s }}")
| shape-error sh |> std/io:print.ln("FAIL shape {{ sh.message:s }}")
| dispatch-error de |> std/io:print.ln("FAIL dispatch {{ de.message:s }}")
| defined d |> std/io:print.ln("FAIL defined {{ d:s }}")
| exhausted _ |> std/io:print.ln("FAIL exhausted")
| partial pa |> std/io:print.ln("FAIL partial")
| scope-not-found snf |> std/io:print.ln("FAIL noscope {{ snf:s }}")

[with]std/bridge:create(id: "b1", scope: "collide"): br
|> ping-turn(br)
