// Test: `std/cell:open(room_state, id: ...)` — the standalone custodian path.
//
// The shape name is comptime: `open`'s transform resolves `room_state` against
// the program's `std/proto(...)` decls. `| cell c` hands the caller the `cell!`
// obligation — owned custody, settled only by `hibernate` (which wants
// `<!cell>`). `run` is a borrow-time dispatch into the session.
//
// Also pins the scoped-custody shape: hibernate lives INSIDE the `| cell` arm
// body (KORU108 — an arm's bindings end with that arm), joined after the run
// dispatch.

~import std/io
~import std/cell
~import std/proto
~import std/runtime

~std/proto(room_state) {
    visits: u32
}

~pub tor greet { name: string } -> string
~greet -> "hello {{ name:s }}"

~std/runtime:register(scope: "cell") {
    greet(5)
}

~std/cell:open(room_state, id: "assistant")
| cell c |> std/cell:run(c, source: "greet(name: \"assistant\")")
  | result r |> std/io:print.ln("cell said: {{ r.bound:s }}")
  | defined d |> std/io:print.ln("defined")
  | unhandled-branch u |> std/io:print.ln("unhandled")
  | exhausted e |> std/io:print.ln("exhausted")
  | parse-error e |> std/io:print.ln("parse-error")
  | residue r2 |> std/io:print.ln("residue")
  | validation-error v |> std/io:print.ln("validation-error")
  | shape-error s |> std/io:print.ln("shape-error")
  | event-denied e |> std/io:print.ln("denied")
  | dispatch-error e |> std/io:print.ln("dispatch-error")
  | scope-not-found s3 |> std/io:print.ln("scope missing")
  |> std/cell:hibernate(c) |> std/io:print.ln("assistant hibernated")
