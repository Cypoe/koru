---
type: belief
id: frag-a-transforms-early-return-skips-its-own-walk
provenance: c-lane store.new C arm, ccomp branch, 2026-10-12 — the
  emitted C carried a raw `acc.n` while the cell declared
  `__koru_store_acc`; ccomp refused `use of undeclared identifier`
ts: 2026-10-12
tags: [koru, transforms, store, c-lane, whole-program-rewrite]
---

# frag-a-transforms-early-return-skips-its-own-walk

A transform that does a whole-program rewrite pass at the end of its
body cannot be early-returned before that pass — the early path skips
rewrites the rest of the pipeline already depends on.

Measured: `std/store:new`'s first C arm guarded, minted its units, and
returned — *above* the `Walk.items` call that lowers every
`<store>.<field>` textual reference in the program (including inside
`{{ ... }}` interpolation payloads, which `expressionMask` marks as
expression context). The emitted C declared `__koru_store_acc` and its
write proc used the lowered name, but the top-level print flow still
said `acc.n` — `use of undeclared identifier 'acc'` at the oracle. The
fix was to move the return *below* the walk and reuse the already-built
`apply_event_item`/`write_event_item` rather than a second set of
decls.

The trap is invisible at the write site: the walk is ~600 lines below
the natural place to branch on host target, and every variable the
late code needs is in scope early. Nothing in the signature says "do
not return before this point." When a transform ends with a
whole-program pass, treat that pass as load-bearing for *every* exit —
including per-target shortcuts — or hoist a comment to the branch point
naming the walk the shortcut must not skip.
