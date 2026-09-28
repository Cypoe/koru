// TEST: introspection is an ordinary wire verb granted per session.
//
// `vocabulary()` and `grammar()` are HOST verbs — not register-block entries,
// not a protocol side channel. `create(introspection: true)` grants them;
// they pass the wire gate, the scope dispatcher denies them, and the host
// table answers. The render is the live session: compiled scope, the host
// verbs themselves, then defined inventions. They arm like any return:
// `vocabulary() | ok v |>` binds the render. An ungranted session hears
// event-denied — the same answer a forged word gets.

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

tor granted-vocab { br: *std/bridge:Bridge }
granted-vocab = std/bridge:run(br, source: "vocabulary()")
| result r |> std/interpreter:value.stringify(r.value): j |> std/io:print.ln("  vocab -> {{ j:s }}")
| event-denied ev |> std/io:print.ln("  FAIL vocab DENIED {{ ev:s }}")
| dispatch-error e |> std/io:print.ln("  FAIL vocab DISPATCH {{ e.message:s }}")
| residue _ |> std/io:print.ln("FAIL: residue outcome")
| parse-error e |> std/io:print.ln("  FAIL vocab PARSE {{ e.message:s }}")
| unhandled-branch u |> std/io:print.ln("  FAIL vocab UNHANDLED {{ u.branch:s }}")
| defined _ |> std/io:print.ln("  FAIL vocab DEFINED")
| exhausted _ |> std/io:print.ln("  FAIL vocab EXHAUSTED")
| validation-error e |> std/io:print.ln("  FAIL vocab VALIDATION {{ e:s }}")
| shape-error _ |> std/io:print.ln("  FAIL vocab SHAPE")
| scope-not-found _ |> std/io:print.ln("  FAIL vocab NO SCOPE")
| partial _ |> std/io:print.ln("  FAIL vocab PARTIAL")

tor granted-chain { br: *std/bridge:Bridge }
granted-chain = std/bridge:run(br, source: "vocabulary()\n| ok v |> echo(text: v)")
| result r |> std/interpreter:value.stringify(r.value): j |> std/io:print.ln("  chained -> {{ j:s }}")
| event-denied ev |> std/io:print.ln("  FAIL chain DENIED {{ ev:s }}")
| dispatch-error e |> std/io:print.ln("  FAIL chain DISPATCH {{ e.message:s }}")
| residue _ |> std/io:print.ln("FAIL: residue outcome")
| parse-error e |> std/io:print.ln("  FAIL chain PARSE {{ e.message:s }}")
| unhandled-branch u |> std/io:print.ln("  FAIL chain UNHANDLED {{ u.branch:s }}")
| defined _ |> std/io:print.ln("  FAIL chain DEFINED")
| exhausted _ |> std/io:print.ln("  FAIL chain EXHAUSTED")
| validation-error e |> std/io:print.ln("  FAIL chain VALIDATION {{ e:s }}")
| shape-error _ |> std/io:print.ln("  FAIL chain SHAPE")
| scope-not-found _ |> std/io:print.ln("  FAIL chain NO SCOPE")
| partial _ |> std/io:print.ln("  FAIL chain PARTIAL")

tor granted-args { br: *std/bridge:Bridge }
granted-args = std/bridge:run(br, source: "vocabulary(extra: \"x\")")
| result r |> std/io:print.ln("  FAIL args RESULT {{ r.value.branch:s }}")
| event-denied ev |> std/io:print.ln("  FAIL args DENIED {{ ev:s }}")
| dispatch-error e |> std/io:print.ln("  args dispatch-error: {{ e.message:s }}")
| residue _ |> std/io:print.ln("FAIL: residue outcome")
| parse-error e |> std/io:print.ln("  FAIL args PARSE {{ e.message:s }}")
| unhandled-branch u |> std/io:print.ln("  FAIL args UNHANDLED {{ u.branch:s }}")
| defined _ |> std/io:print.ln("  FAIL args DEFINED")
| exhausted _ |> std/io:print.ln("  FAIL args EXHAUSTED")
| validation-error e |> std/io:print.ln("  FAIL args VALIDATION {{ e:s }}")
| shape-error _ |> std/io:print.ln("  FAIL args SHAPE")
| scope-not-found _ |> std/io:print.ln("  FAIL args NO SCOPE")
| partial _ |> std/io:print.ln("  FAIL args PARTIAL")

tor do-define { br: *std/bridge:Bridge }
do-define = std/bridge:define(br, source: "tor shout { text: string }\nshout = echo(text)")
| defined d |> std/io:print.ln("  defined {{ d:s }}")
| parse-error e |> std/io:print.ln("  FAIL define PARSE {{ e.message:s }}")

tor granted-post-define { br: *std/bridge:Bridge }
granted-post-define = std/bridge:run(br, source: "vocabulary()")
| result r |> std/interpreter:value.stringify(r.value): j |> std/io:print.ln("  vocab+def -> {{ j:s }}")
| event-denied ev |> std/io:print.ln("  FAIL vocab2 DENIED {{ ev:s }}")
| dispatch-error e |> std/io:print.ln("  FAIL vocab2 DISPATCH {{ e.message:s }}")
| residue _ |> std/io:print.ln("FAIL: residue outcome")
| parse-error e |> std/io:print.ln("  FAIL vocab2 PARSE {{ e.message:s }}")
| unhandled-branch u |> std/io:print.ln("  FAIL vocab2 UNHANDLED {{ u.branch:s }}")
| defined _ |> std/io:print.ln("  FAIL vocab2 DEFINED")
| exhausted _ |> std/io:print.ln("  FAIL vocab2 EXHAUSTED")
| validation-error e |> std/io:print.ln("  FAIL vocab2 VALIDATION {{ e:s }}")
| shape-error _ |> std/io:print.ln("  FAIL vocab2 SHAPE")
| scope-not-found _ |> std/io:print.ln("  FAIL vocab2 NO SCOPE")
| partial _ |> std/io:print.ln("  FAIL vocab2 PARTIAL")

tor denied-vocab { br: *std/bridge:Bridge }
denied-vocab = std/bridge:run(br, source: "vocabulary()")
| result r |> std/io:print.ln("  FAIL denied RESULT {{ r.value.branch:s }}")
| event-denied ev |> std/io:print.ln("  denied: event-denied {{ ev:s }}")
| dispatch-error e |> std/io:print.ln("  FAIL denied DISPATCH {{ e.message:s }}")
| residue _ |> std/io:print.ln("FAIL: residue outcome")
| parse-error e |> std/io:print.ln("  FAIL denied PARSE {{ e.message:s }}")
| unhandled-branch u |> std/io:print.ln("  FAIL denied UNHANDLED {{ u.branch:s }}")
| defined _ |> std/io:print.ln("  FAIL denied DEFINED")
| exhausted _ |> std/io:print.ln("  FAIL denied EXHAUSTED")
| validation-error e |> std/io:print.ln("  FAIL denied VALIDATION {{ e:s }}")
| shape-error _ |> std/io:print.ln("  FAIL denied SHAPE")
| scope-not-found _ |> std/io:print.ln("  FAIL denied NO SCOPE")
| partial _ |> std/io:print.ln("  FAIL denied PARTIAL")

[with]std/bridge:create(id: "s1", scope: "echo", introspection: true): br
|> std/io:print.ln("--- granted session")
|> granted-vocab(br)
|> granted-chain(br)
|> granted-args(br)
|> do-define(br)
|> granted-post-define(br)
|> std/io:print.ln("--- ungranted session")
|> std/bridge:create(id: "s2", scope: "echo"): br2
|> denied-vocab(br: br2)
|> std/io:print.ln("--- done")
