---
type: belief
id: frag-the-transformed-mark-is-per-node-not-per-subtree
provenance: 2026-10-18 — std/store:stored's multi-field envwrite chain left the authored tail a child of a marked node; the phantom checker pruned on the mark and never validated the tail
ts: 2026-10-18
---

`is_transformed_subtree` marks a synthesized NODE, not a region. A transform
that bottoms its graft out in the flow's own continuations leaves authored
code as a CHILD of a marked node — and a checker that returns early on the
mark has just skipped user code.

The mark exists so synthesized machinery isn't linearity-judged as if it were
authored straight-line flow (a fused loop body re-uses iteration bindings and
reads as false use-after-discharge). That exemption is for the synthesized
node only. Children carry their own marks; the correct walk skips the marked
node's own step validation but still descends — resolving the synthesized
node's invoked tor and dispatching the children against it, exactly as any
other invocation's arms are dispatched.

A validator that prunes on the mark converts "this node was generated" into
"everything beneath this node is invisible" — and which checks silently vanish
then depends on which transform the surface text happened to trigger, a
verdict that varies with store-field count rather than with semantics
(330_145's masked path: a two-field `stored` hid `window.size(win: w)`).
When the graft node's invoked tor can't be resolved the old blanket-skip remains —
better an unvalidated graft than a guessed dispatch — but an authored tail
must never ride the exemption of the node that happens to parent it.
