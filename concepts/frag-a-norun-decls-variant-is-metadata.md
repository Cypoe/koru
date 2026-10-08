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

`path(args)|variant` is three different sentences depending on the callee. On a
runnable event it is dispatch: "call the `|dev` proc" — the emitter writes
`handler__dev`, and a missing variant proc is a broken program. On a `[norun]`
decl the call never dispatches anything — the site is AST data a collector
reads — so `|variant` there means "this declaration carries build-name
metadata," and the only honest handler emission is the base one. On a
`[transform]` decl it is *input*: the transform reads `inv.variant` to select
its artifact pipeline — `std/kernel:self|mlir` names the language the kernel's
output is written in, not a proc to dispatch to (`const|template|js` follows
the same convention).

The dividing line is *declared* variant procs, not the annotation alone: a
`[norun]` decl that actually declares `proc name|dev` still dispatches
`handler__dev`. The emitter consults `findVariantProcsByPath` before deciding —
no variant impl, no dispatch, base handler.

Prior to this ruling the call site assumed every `|variant` named a proc —
stack hit it as `service_event has no member named 'handler__dev'` at backend
compile, a semantic refusal that arrived as a Zig type error. The subflow-head
path (`emitEventDecl`'s inner-invocation site) carried the same assumption and
got the same guard.

The KORU177 call-site wall (misspelled `f|zig(gdoot)` would emit a
`handler__zig_28_gdoot_29_` that exists nowhere) made the same conflation at
the checker layer: it fired on `self|mlir` and `tag|dev` because a `|zig`
sibling proc exists. The wall must honor the same dividing line the emitter
does — `[transform]` and `[norun]` decls are exempt alongside `abstract`; only
an undecorated runnable event's call-site `|variant` is a proc-target claim
that can be misspelled.

Pinned by 310_138, 390_100..105, 390_121..126.
