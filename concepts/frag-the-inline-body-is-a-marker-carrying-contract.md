---
type: belief
id: frag-the-inline-body-is-a-marker-carrying-contract
provenance: `if` inside an orisha:router arm compiled at the Koru level and then failed the Zig build with raw `__koru_continue_0`/`_1` markers in output_emitted.zig — found porting once-campfire, where a route arm legitimately wants to branch
ts: 2026-10-05
tags: [koru, transforms, inline-body, continuation-splice, emitter-parity]
---

# A template's inline_body is a marker-carrying contract, and every emit path must honour it

`[template]` procs (`if`, `cond`, `for`, …) do not emit Zig directly. They
emit a body containing markers — `__koru_continue_N`, `__koru_continue_bare_N`,
`__koru_inline_N(arg)`, `__koru_inline_scoped_N(arg)` — that are **not Zig and
never may reach Zig**. Resolving them is part of emitting the body, not an
optional extra.

The defect this pins: koru has (at least) two paths that write
`inv.inline_body` into the output — the CodeEmitter path
(`emitInlineCodeResolvingSplices`, which scans for the markers and splices the
referenced continuations with guards, binding puns, shadow-renames,
destructures, and nested result-prefix namespaces) and the string-codegen path
(`continuation_codegen.generatePipelineCode`, used by transforms that lower a
continuation chain to text — orisha:router's per-route-arm bodies). The second
path appended the body verbatim. Any `if`/`cond`/`for` inside a route arm
therefore leaked its markers into `output_emitted.zig` and the failure surfaced
one stage downstream as `error: expected ';' after statement`.

The belief: **the markers are part of the inline_body contract, not part of
the emitter.** A path that writes an inline_body without resolving its markers
is a broken emitter no matter how many tests it passes — the corpus simply
hadn't put a control template inside a transform-consumed arm. The fix lands
the same contract on the string path (`resolveInlineMarkers`): same marker
grammar, same splice shape `{ [if (guard)] { <arm chain> } }`, same
`__koru_bind_L_C` shadow-rename, same `{prefix}c<idx>_`/`e<idx>_` result
namespaces.

Two honest debts this leaves:

- **There are now two resolvers.** `emitter_helpers` writes directly;
  `resolveInlineMarkers` builds strings. They share a spec (the marker
  grammar) but not code. A drift between them is the exact bug class this
  commit fixes, one level up — the end-state is one resolver over a write
  interface, or a documented freeze point both call.
- **The resolver family is now pinned at three marker kinds.**
  350_030_router_if_template_arm covers `__koru_continue_N`;
  350_027_router_for_template_arm covers the arg-carrying effect splice
  (`__koru_inline_scoped_N(__koru_item)` for `! each`, plus `done`'s
  continue); 350_028_router_cond_template_arm covers `__koru_continue_bare_N`
  (guarded arms, where the template owns the `if`). Remaining by-construction
  surface: the shadow-rename (`__koru_bind_L_C`) and destructure paths fire
  only on collisions/shape-binds no route arm has needed yet.

Sister to `frag-vocabulary-is-not-evidence-of-what-a-transform-emits`: there,
surface vocabulary was mistaken for output; here, one emit path's fidelity was
mistaken for all emit paths' fidelity. Both fail the same way — judging a
transform's emission by reading the convenient path instead of the one the
program actually takes.
