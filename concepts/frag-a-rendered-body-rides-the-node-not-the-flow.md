---
type: belief
id: frag-a-rendered-body-rides-the-node-not-the-flow
provenance: 2026-10-12 — asteroids paint-rocks: `for(0..9)` under a `! query` arm
  emitted `for_event.handler(.{ .expr = 0..9 })` on the zig lane — a dropped loop
  and a verbatim range literal in a struct init — while the JS lane emitted the
  loop correctly
ts: 2026-10-12
tags: [emitter, template, transform, store]
resource: src/visitor_emitter.zig (subflow-impl dispatch), src/emitter_helpers.zig (emitFlow)
---

# A rendered body rides the node, not the flow (belief)

`inline_body` has two homes and they are not interchangeable.
`maybeRenderPerCall` writes `flow.inline_body` when the template is the
flow's own head; `renderNestedTemplates` writes `node.invocation.inline_body`
when it is nested inside a continuation. The pass runs BEFORE the main-stage
transforms — so a transform that relocates a rendered node (`std/store:query`
transplanting a `! query` arm into a synthesized `__store_sweepbody` flow)
carries the body on the INVOCATION while the fresh flow's `inline_body`
stays null.

Every head-dispatch site must therefore read `flow.inline_body orelse
flow.inv().inline_body`. The zig subflow-impl dispatch read only the first,
and the failure was quiet about it: no "unrendered template" diagnostic —
just the raw event call emitted with the range literal pasted into the
argument struct, invalid Zig that surfaced as `expected ',' after
initializer` three files away from the cause.

The JS lane never hit this because its dispatch funnels the head through
`emitInvocationWithContinuations`, which reads the invocation field. The
divergence is the tell worth keeping: **when two lanes disagree about a
lowered artifact, the field being read is usually the difference** — not
the pass, not the transform, not the syntax.

Pinned by 690_308 (`for` under `! query`, dual-lane). Sibling belief:
frag-a-continuations-owner-is-written-in-its-branch-name — same family of
"the pass wrote it here, the emit looked there."
