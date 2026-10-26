// TEST: MOUNTED SCOPE — a `.dylib` extends a live session's vocabulary,
// on the resources the session already holds, without reloading them.
//
// The claim this pins, end to end:
//
//   1. The bound scope `open` mints a `*Note<opened>` handle on the bridge.
//   2. `std/bridge:mount` dlopens module/zig-out/lib/libspike.dylib — a
//      hand-built scope carrying the same ScopeRuntime vtable `register`
//      emits — and installs it on the session.
//   3. The mounted verb `touch(handle: *Note<opened>)` borrows the
//      base-minted handle THROUGH THE SAME POOL — the module resolves the
//      token via the host services and reads note.text. Its result
//      carries the note's own text: `touched:first-note` is proof the
//      module read the resource, not a copy.
//   4. The mounted verb `seal` mints `*Stamp<sealed>` — booked against
//      the same pool — discharged explicitly by `unseal`.
//   5. `vocabulary()` renders the mounted verbs beside the compiled ones
//      — prompt and enforcement read one table.
//   6. A second stamp is left held: hang-up sweeps it through the
//      MODULE's dispatcher — cross-scope discharge. Reaching the final
//      print at all is the assertion: a stranded handle panics `close`.
//
// Minted tokens are never printed — they are random hex — only counts,
// bound names, and the module's own strings.

import std/io
import std/bridge
import app/session

tor step { br: *std/bridge:Bridge<session>, source: string<*>, tag: string }
step = std/bridge:run(br, source)
| result r |> std/io:print.ln("{{ tag:s }} ok (holds {{ r.handles:d }}, bound {{ r.bound:s }})")
| unhandled-branch ub |> std/io:print.ln("{{ tag:s }} FAIL unhandled {{ ub.branch:s }}")
| defined d |> std/io:print.ln("{{ tag:s }} FAIL defined {{ d:s }}")
| error runerr |> std/bridge:error-decode(e: runerr)
    | dispatch-error e |> std/io:print.ln("{{ tag:s }} refused: {{ e.message:s }}")
    | event-denied ev |> std/io:print.ln("{{ tag:s }} FAIL denied {{ ev:s }}")
    | parse-error p |> std/io:print.ln("{{ tag:s }} FAIL parse {{ p.message:s }}")
    | validation-error v |> std/io:print.ln("{{ tag:s }} FAIL invalid {{ v:s }}")
    | shape-error sh |> std/io:print.ln("{{ tag:s }} FAIL shape {{ sh.message:s }}")
    | exhausted _ |> std/io:print.ln("{{ tag:s }} FAIL exhausted")
    | scope-not-found s2 |> std/io:print.ln("{{ tag:s }} FAIL noscope {{ s2:s }}")
| residue _ |> std/io:print.ln("{{ tag:s }} FAIL residue outcome")
| partial p |> std/io:print.ln("{{ tag:s }} FAIL partial {{ p.ran:d }}/{{ p.total:d }}")

// Same step, but the result VALUE is rendered — for `touch`, whose
// payload is the proof a mounted verb read a base-minted resource.
tor step-show { br: *std/bridge:Bridge<session>, source: string<*>, tag: string }
step-show = std/bridge:run(br, source)
| result r |> std/interpreter:value.stringify(r.value): j |> std/io:print.ln("{{ tag:s }} ok -> {{ j:s }}")
| unhandled-branch ub |> std/io:print.ln("{{ tag:s }} FAIL unhandled {{ ub.branch:s }}")
| defined d |> std/io:print.ln("{{ tag:s }} FAIL defined {{ d:s }}")
| error runerr |> std/bridge:error-decode(e: runerr)
    | dispatch-error e |> std/io:print.ln("{{ tag:s }} refused: {{ e.message:s }}")
    | event-denied ev |> std/io:print.ln("{{ tag:s }} FAIL denied {{ ev:s }}")
    | parse-error p |> std/io:print.ln("{{ tag:s }} FAIL parse {{ p.message:s }}")
    | validation-error v |> std/io:print.ln("{{ tag:s }} FAIL invalid {{ v:s }}")
    | shape-error sh |> std/io:print.ln("{{ tag:s }} FAIL shape {{ sh.message:s }}")
    | exhausted _ |> std/io:print.ln("{{ tag:s }} FAIL exhausted")
    | scope-not-found s2 |> std/io:print.ln("{{ tag:s }} FAIL noscope {{ s2:s }}")
| residue _ |> std/io:print.ln("{{ tag:s }} FAIL residue outcome")
| partial p |> std/io:print.ln("{{ tag:s }} FAIL partial {{ p.ran:d }}/{{ p.total:d }}")

tor mount-spike { br: *std/bridge:Bridge<session>, path: string }
mount-spike = std/bridge:mount(br, path)
| mounted m |> std/io:print.ln("mounted scope: {{ m:s }}")
| failed f |> std/io:print.ln("MOUNT FAILED: {{ f:s }}")

tor show-vocab { br: *std/bridge:Bridge<session> }
show-vocab = std/bridge:vocabulary(br)
| ok v |> std/io:print.ln("vocabulary:\n{{ v:s }}")
| not-found _ |> std/io:print.ln("vocabulary: not-found")

tor show-grammar { br: *std/bridge:Bridge<session> }
show-grammar = std/bridge:grammar(br)
| ok g |> std/io:print.ln("grammar:\n{{ g:s }}")
| not-found _ |> std/io:print.ln("grammar: not-found")

tor show-held { br: *std/bridge:Bridge<session> }
show-held = std/bridge:get-handles(br): hc |> std/io:print.ln("held before hang-up: {{ hc:d }}")

[with]std/bridge:create(id: "mounted-1", scope: "notes", introspection: true): br
|> app/session:build-module(): lib
|> step(br, source: "open(path: \"first-note\")", tag: "open")
|> mount-spike(br, path: lib)
|> step-show(br, source: "touch(handle: r1)", tag: "touch")
|> step(br, source: "seal(label: \"wax\")", tag: "seal")
|> step(br, source: "unseal(stamp: r3)", tag: "unseal")
|> step(br, source: "unseal(stamp: r3)", tag: "reunseal")
|> show-vocab(br)
|> show-grammar(br)
|> step(br, source: "seal(label: \"held\")", tag: "seal2")
|> show-held(br)
|> close(br) |> std/io:print.ln("hang-up: clean")
