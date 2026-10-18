---
type: belief
id: frag-a-bound-record-produce-repacks-fieldwise-into-the-declared-output
provenance: 2026-11-04 — frontier-emit + frontier-ledger both reproduced the producing-if collision independently (020_065, 330_100): `-> r` under a declared `-> {record}` emitted the callee's Output type where the caller's was expected
ts: 2026-11-04
---

# A bound-record produce repacks fieldwise into the declared Output (belief)

Two tors' record returns are nominally distinct Zig types even when
field-identical — `pick_event.Output` and `__koru_handler_impl__struct_N` do
not unify. A bare-return produce that names a BOUND record (`-> r`, where `r`
came from another tor or an earlier step) therefore cannot emit the value
verbatim: it must repack field-by-field against the enclosing tor's declared
record — `.{ .a = r.a, .b = r.b }` — so the result carries the caller's own
`Output` type.

The repack applies only to identifier paths. A literal `{ ... }` produce
already emits field-wise; a call or computed expression in the produce slot
keeps its own boundary type (the callee's contract) — and repacking it would
evaluate the call once per field, duplicating side effects. `isIdentPath` is
the guard, not an optimization.

Pinned by 020_065 (if-arm produce + chain tail) and load-bearing for the
obligation thread: 330_100's pass-through `-> r` only reaches codegen because
the repack makes the record's type honest at the boundary.

## Open question

Two independent contestants minted this fix in the same week (emit and ledger,
each blind to the other). The wall was that easy to hit — worth remembering
when the next boundary type collision surfaces.
