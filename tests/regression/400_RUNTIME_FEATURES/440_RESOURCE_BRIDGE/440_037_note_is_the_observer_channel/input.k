// TEST: `note` is the observer channel — a host verb, not vocabulary.
//
// Granted by `create(introspection: true)` alongside vocabulary/grammar/
// bind. The result is a bare `ok` acknowledgment: the note's text is already
// durable in the turn's wire source, and echoing it as the result would
// re-feed the model its own prose every report. It never becomes a `say` —
// the scope dispatcher never sees it. A `note` with no `text:` field fails
// with teaching. A `note(...)` glued to a same-line call
// (`note(...)say(...)`) splits at the call: the note binds as residue, the
// tail still runs. In an ungranted session `note` is event-denied, the same
// answer any unknown word gets — the observer channel exists only where the
// session was built to be observed.

import std/io
import std/bridge
import std/runtime
import std/interpreter

tor echo { text: string } -> string
proc echo|zig {
    return text;
}

std/runtime:register(scope: "echo") {
    echo(1)
}

tor noted { br: *std/bridge:Bridge<session> }
noted = std/bridge:run(br, source: "note(text: \"checking tier before touching the reservation\")")
| result r |> std/interpreter:value.stringify(r.value): j |> std/io:print.ln("  note -> {{ j:s }} bound: {{ r.bound:s }}")
| error runerr |> std/bridge:error-decode(e: runerr)
    | event-denied ev |> std/io:print.ln("  FAIL note DENIED {{ ev:s }}")
    | dispatch-error e |> std/io:print.ln("  FAIL note DISPATCH {{ e.message:s }}")
    | parse-error e |> std/io:print.ln("  FAIL note PARSE {{ e.message:s }}")
    | exhausted _ |> std/io:print.ln("  FAIL note EXHAUSTED")
    | validation-error e |> std/io:print.ln("  FAIL note VALIDATION {{ e:s }}")
    | shape-error _ |> std/io:print.ln("  FAIL note SHAPE")
    | scope-not-found _ |> std/io:print.ln("  FAIL note NO SCOPE")
| residue _ |> std/io:print.ln("FAIL: residue outcome")
| unhandled-branch u |> std/io:print.ln("  FAIL note UNHANDLED {{ u.branch:s }}")
| defined _ |> std/io:print.ln("  FAIL note DEFINED")
| partial _ |> std/io:print.ln("  FAIL note PARTIAL")

tor note-chain { br: *std/bridge:Bridge<session> }
note-chain = std/bridge:run(br, source: "note(text: \"plan: greet, then book\")\n| ok n |> echo(text: n)")
| result r |> std/interpreter:value.stringify(r.value): j |> std/io:print.ln("  chain -> {{ j:s }}\n{{ r.trace:s }}")
| error runerr |> std/bridge:error-decode(e: runerr)
    | event-denied ev |> std/io:print.ln("  FAIL chain DENIED {{ ev:s }}")
    | dispatch-error e |> std/io:print.ln("  FAIL chain DISPATCH {{ e.message:s }}")
    | parse-error e |> std/io:print.ln("  FAIL chain PARSE {{ e.message:s }}")
    | exhausted _ |> std/io:print.ln("  FAIL chain EXHAUSTED")
    | validation-error e |> std/io:print.ln("  FAIL chain VALIDATION {{ e:s }}")
    | shape-error _ |> std/io:print.ln("  FAIL chain SHAPE")
    | scope-not-found _ |> std/io:print.ln("  FAIL chain NO SCOPE")
| residue _ |> std/io:print.ln("FAIL: residue outcome")
| unhandled-branch u |> std/io:print.ln("  FAIL chain UNHANDLED {{ u.branch:s }}")
| defined _ |> std/io:print.ln("  FAIL chain DEFINED")
| partial _ |> std/io:print.ln("  FAIL chain PARTIAL")

tor note-no-arg { br: *std/bridge:Bridge<session> }
note-no-arg = std/bridge:run(br, source: "note()")
| result r |> std/io:print.ln("  FAIL noarg RESULT {{ r.value.branch:s }}")
| error runerr |> std/bridge:error-decode(e: runerr)
    | event-denied ev |> std/io:print.ln("  FAIL noarg DENIED {{ ev:s }}")
    | dispatch-error e |> std/io:print.ln("  noarg dispatch-error: {{ e.message:s }}")
    | parse-error e |> std/io:print.ln("  FAIL noarg PARSE {{ e.message:s }}")
    | exhausted _ |> std/io:print.ln("  FAIL noarg EXHAUSTED")
    | validation-error e |> std/io:print.ln("  FAIL noarg VALIDATION {{ e:s }}")
    | shape-error _ |> std/io:print.ln("  FAIL noarg SHAPE")
    | scope-not-found _ |> std/io:print.ln("  FAIL noarg NO SCOPE")
| residue _ |> std/io:print.ln("FAIL: residue outcome")
| unhandled-branch u |> std/io:print.ln("  FAIL noarg UNHANDLED {{ u.branch:s }}")
| defined _ |> std/io:print.ln("  FAIL noarg DEFINED")
| partial _ |> std/io:print.ln("  FAIL noarg PARTIAL")

tor note-rname { br: *std/bridge:Bridge<session> }
note-rname = std/bridge:run(br, source: "note(text: r1)")
| result r |> std/interpreter:value.stringify(r.value): j |> std/io:print.ln("  note-rN -> {{ j:s }}")
| error runerr |> std/bridge:error-decode(e: runerr)
    | event-denied ev |> std/io:print.ln("  FAIL note-rN DENIED {{ ev:s }}")
    | dispatch-error e |> std/io:print.ln("  FAIL note-rN DISPATCH {{ e.message:s }}")
    | parse-error e |> std/io:print.ln("  FAIL note-rN PARSE {{ e.message:s }}")
    | exhausted _ |> std/io:print.ln("  FAIL note-rN EXHAUSTED")
    | validation-error e |> std/io:print.ln("  FAIL note-rN VALIDATION {{ e:s }}")
    | shape-error _ |> std/io:print.ln("  FAIL note-rN SHAPE")
    | scope-not-found _ |> std/io:print.ln("  FAIL note-rN NO SCOPE")
| residue _ |> std/io:print.ln("FAIL: residue outcome")
| unhandled-branch u |> std/io:print.ln("  FAIL note-rN UNHANDLED {{ u.branch:s }}")
| defined _ |> std/io:print.ln("  FAIL note-rN DEFINED")
| partial _ |> std/io:print.ln("  FAIL note-rN PARTIAL")

tor note-tail { br: *std/bridge:Bridge<session> }
note-tail = std/bridge:run(br, source: "note(text: bare prose, the natural spelling)echo(text: \"reached\")")
| result r |> std/io:print.ln("  FAIL tail RESULT {{ r.value.branch:s }}")
| error runerr |> std/bridge:error-decode(e: runerr)
    | event-denied ev |> std/io:print.ln("  FAIL tail DENIED {{ ev:s }}")
    | dispatch-error e |> std/io:print.ln("  FAIL tail DISPATCH {{ e.message:s }}")
    | parse-error e |> std/io:print.ln("  FAIL tail PARSE {{ e.message:s }}")
    | exhausted _ |> std/io:print.ln("  FAIL tail EXHAUSTED")
    | validation-error e |> std/io:print.ln("  FAIL tail VALIDATION {{ e:s }}")
    | shape-error _ |> std/io:print.ln("  FAIL tail SHAPE")
    | scope-not-found _ |> std/io:print.ln("  FAIL tail NO SCOPE")
| residue _ |> std/io:print.ln("  FAIL tail RESIDUE (tail swallowed)")
| unhandled-branch u |> std/io:print.ln("  FAIL tail UNHANDLED {{ u.branch:s }}")
| defined _ |> std/io:print.ln("  FAIL tail DEFINED")
| partial p |> std/io:print.ln("  tail partial wire_failures={{ p.wire_failures:d }}\n{{ p.report:s }}")

tor denied-note { br: *std/bridge:Bridge<session> }
denied-note = std/bridge:run(br, source: "note(text: \"can you hear me\")")
| result r |> std/io:print.ln("  FAIL denied RESULT {{ r.value.branch:s }}")
| error runerr |> std/bridge:error-decode(e: runerr)
    | event-denied ev |> std/io:print.ln("  denied: event-denied {{ ev:s }}")
    | dispatch-error e |> std/io:print.ln("  FAIL denied DISPATCH {{ e.message:s }}")
    | parse-error e |> std/io:print.ln("  FAIL denied PARSE {{ e.message:s }}")
    | exhausted _ |> std/io:print.ln("  FAIL denied EXHAUSTED")
    | validation-error e |> std/io:print.ln("  FAIL denied VALIDATION {{ e:s }}")
    | shape-error _ |> std/io:print.ln("  FAIL denied SHAPE")
    | scope-not-found _ |> std/io:print.ln("  FAIL denied NO SCOPE")
| residue _ |> std/io:print.ln("FAIL: residue outcome")
| unhandled-branch u |> std/io:print.ln("  FAIL denied UNHANDLED {{ u.branch:s }}")
| defined _ |> std/io:print.ln("  FAIL denied DEFINED")
| partial _ |> std/io:print.ln("  FAIL denied PARTIAL")

[with]std/bridge:create(id: "s1", scope: "echo", introspection: true): br
|> std/io:print.ln("--- granted session")
|> noted(br)
|> note-chain(br)
|> note-no-arg(br)
|> note-rname(br)
|> note-tail(br)
|> std/io:print.ln("--- ungranted session")
|> std/bridge:create(id: "s2", scope: "echo"): br2
|> denied-note(br: br2)
|> std/io:print.ln("--- done")
