---
type: belief
id: frag-a-merge-must-remeasure-its-own-board
provenance: 2026-09-08 ceremony — the 430_056 board finally measured, 34 reds found
ts: 2026-09-08
---

# A merge that changes run/bridge/eval semantics must re-measure its own board

The 430_056 merge (e2c9bfc9 + 7e769a4f) landed with its own board unmeasured:
34 failures sat on main — 29 tests whose run/bridge:run switches predated the
`unhandled-branch` arm (KORU022 totality), 2 grammar pins for the sequencing
text, and 2 genuine koru_std inconsistencies the merge itself shipped:

- `std/runtime:eval`'s declared outcome union lacked `unhandled-branch` while
  its zig return gained it — a switch on `eval` was impossible to write and
  the runtime's own internal eval switch didn't forward the branch.
- The comptime mirror + registry walls went stale against the part-split
  (store.query.kz keys) and the std-side refusal emits (`.KORUxxx` in .kz
  files, invisible to a .zig-only scan) — both walls read green for the
  wrong reason.

The lesson: a merge that changes the interpreter/bridge outcome contract
carries a debt the baton's "pins match" cannot see. The board is the only
instrument that measures it — the ceremony must run one after such a merge,
before the narrative moves on. "Installed koruc = main; live.k compiles"
was true; the board was not measured, and 34 reds rode the merge.

What would correct this: the ceremony script growing a post-merge mandatory
board, or a CI gate that fails a merge whose koru_std/bridge/runtime surface
changed without a fresh snapshot.
