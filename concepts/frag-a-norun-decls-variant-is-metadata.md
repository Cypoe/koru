---
type: belief
id: frag-a-norun-decls-variant-is-metadata
provenance: stack's `service(db)|dev` spelled a per-build service redefinition;
  the emitter dispatched `handler__dev` on an event struct that has no such
  member — surfaced as a backend Zig error, not a frontend refusal
ts: 2026-10-05
tags: [variants, norun, emission, decl-grammar]
---

# A `[norun]` decl's `|variant` is declaration metadata, not proc dispatch (belief)

`path(args)|variant` is two different sentences depending on the callee. On a
runnable event it is dispatch: "call the `|dev` proc" — the emitter writes
`handler__dev`, and a missing variant proc is a broken program. On a `[norun]`
decl the call never dispatches anything — the site is AST data a collector
reads — so `|variant` there means "this declaration carries build-name
metadata," and the only honest handler emission is the base one.

The dividing line is *declared* variant procs, not the annotation alone: a
`[norun]` decl that actually declares `proc name|dev` still dispatches
`handler__dev`. The emitter consults `findVariantProcsByPath` before deciding —
no variant impl, no dispatch, base handler.

Prior to this ruling the call site assumed every `|variant` named a proc —
stack hit it as `service_event has no member named 'handler__dev'` at backend
compile, a semantic refusal that arrived as a Zig type error. The subflow-head
path (`emitEventDecl`'s inner-invocation site) carried the same assumption and
got the same guard.

Pinned by 310_138.
