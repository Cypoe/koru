---
type: belief
id: frag-a-walk-that-cannot-see-grafted-leaves-drops-live-events
provenance: 2026-10-07 — ponkatris `collect`/`reset` sweeps on --lang=js: the minted `__store_sweepbody_*` events were called by the emitted sweeprun and never emitted; node answered `undefined.handler` every frame
ts: 2026-10-07
tags: [js-target, implementability, transform]
resource: src/js_emitter.zig (continuationsAreJsImplementable)
---

# A gate that cannot see grafted node kinds drops live events (belief)

The JS emitter's implementability walk (`eventIsJsImplementable` →
`continuationsAreJsImplementable`) exists to keep a dead handler from
panicking a live compile: an event whose body bottoms out in Zig-only
machinery stays absent, deliberately. Its leaf vocabulary was the PARSED
one — invocation, label-with-invocation, terminal, branch_constructor —
and anything else answered "cannot vouch."

The vocabulary it must vouch for is the POST-PASS one. A `| ?!` panic
branch the site never wrote arrives as `.inline_code`, grafted by
auto_discharge_inserter — no source, no invocation, a leaf. The walk
refused it, so the minted `__store_sweepbody_*` event was judged
unimplementable, skipped, AND invisible to `reached` (its only caller is
transform-emitted text inside the sweeprun, which no AST walk can see).
Both gates failed the same event for different reasons; the failure
surfaced one layer down as `Cannot read properties of undefined (reading
'handler')` — the exact `undefined.handler` shape the refusal-stub path
was built to prevent, produced by the gate itself.

The rule: **a conservative gate over lowered artifacts must key on what
the emitter will DO with the node, not on the node's lineage.** The fix
was not "accept inline_code" — a dead event carrying unlowering Zig text
under that tag is the 115_024 hazard the gate exists for — it was
trial-lowering the text the same way `emitPreamble` will, so the walk's
verdict and the emitter's verdict cannot disagree.

## What follows

- **When a gate vets a node kind, ask who minted it.** `.inline_code`,
  `.metatype_binding`, `.assignment` are grafted by passes, not written —
  a walk built over the parser's vocabulary silently un-vets the whole
  grafted family. The remaining refuse-by-default set still contains
  kinds `emitVoidStatementNode` can emit; each is this same bug waiting
  for its site.
- **"Implementable" is a question only the lowering can answer.** Where a
  leaf carries opaque text, the gate should RUN the lowering, not guess
  at it — the trial is cheap and the two verdicts then share one code
  path.
- **The `reached` set cannot see transform-text call sites.** Any event
  invoked only from another event's `inline_body`/`|js` body is absent
  from the AST walk; if such an event ever fails implementability it
  gets neither a body nor a refusal stub. That hole remains — today it
  is silent only because nothing unimplementable is reachable that way.

Related: [[frag-a-transform-proc-had-no-js-variant-machinery]] — the same
seam one level up: the `|js` tag's meaning splits between "this body IS
JavaScript" and "this variant EMITS JavaScript", and confusing the two is
how Zig text reached the emitted file.
