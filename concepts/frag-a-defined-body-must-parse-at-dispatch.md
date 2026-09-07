---
type: belief
id: frag-a-defined-body-must-parse-at-dispatch
provenance: armed-define fix, 2026-09-07 — runtime define accepted armed bodies at install and refused them at dispatch
ts: 2026-09-07
tags: [koru, interpreter, define, flow-parser, parity, agent-channel]
---

# A defined body must parse at dispatch (belief)

`define` stores a body as source and re-parses it on every dispatch, through
a *different, lighter* parser than the one that validated it at install.
Whenever those two accept different languages, the wire grows a shape that
installs and never runs — and the refusal names nothing the model did wrong,
because the model did nothing wrong.

The invariant, stated once so both ends can be held to it: **a body legal at
define time must dispatch; a dispatch refusal of a defined body is a parity
defect, never a model error.** The sibling rule for the call channel lives
in the wire-grammar concept (parse-error vs event-denied vs
validation-error); this is its define-channel twin: install-time and
dispatch-time accept one language.

What would `correct` this: a ruling that defined bodies are *intentionally* a
sub-language (single-invocation only, say) — at which point the refusal is
policy, install must refuse it too, and this belief was never right.
