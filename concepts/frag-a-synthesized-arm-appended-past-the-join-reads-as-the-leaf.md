---
type: belief
id: frag-a-synthesized-arm-appended-past-the-join-reads-as-the-leaf
provenance: 400_204 — absent `| else` on `std/control:if` minted a second
  discharge and double-freed; found via the related-posts benchmark, whose
  absent-else guard freed a cell mid-flight
ts: 2026-10-03
tags: [koru, auto-discharge, continuation, synthesized-arms, join]
---

# A synthesized arm appended past the join reads as the leaf (belief)

In a transformed continuation list, an unnamed continuation after named arms is
the construct's join — "after the conditional" — and the discharge walk's leaf
detection is *positional*: `joinFollows` scans forward for an unnamed sibling,
and the deep-exit appender descends `continuations[n-1]`. Position is the
semantics.

The optional-arm synthesizers appended unhandled `| ?` arms at list end — past
the anonymous join tail. A synthesized no-op arm landing there is read by every
positional consumer as *the leaf*, not as a sibling of the join. The discharge
walk then settled join-live obligations inside it: an absent `| else` on `if`
emitted `else { drop(r) }` and the join emitted `drop(r)` again. Crash-134,
every false-path run.

The fix is two halves, and either alone is wrong:

- Synthesized named arms insert *before* the first anonymous continuation, so
  `joinFollows` sees the join past them and the watermark stamps at arm entry.
- The explicit-`.terminal` leaf check (`checkContinuation`) now honors
  `join_watermark` the way the implicit-terminal leaf already did. Without it,
  a watermark-protected arm ending in a real `.terminal` still settles
  live-through obligations early.

Either fix alone leaves a hole: reposition without the watermark still
discharges inside a `.terminal` leaf; the watermark without repositioning never
stamps for an arm sitting last.

The general belief, sibling to
`frag-a-synthesized-safety-arm-only-exists-where-the-pass-looked`: **a pass
that mints AST is composing with positional readers it cannot see.** Where the
pass looked was half the contract; *where it wrote* is the other half. Any
synthesis that appends to a list whose readers are positional must place its
product in the position whose meaning it intends — arms before joins, leaves
last — or it mints a leaf where it meant a noop.

Two sites had the same defect (`synthesizeOptionalBranches` at flow heads,
`loudArmsFor` on nested invocations) because they were written as independent
append-to-end emitters. The 400_193 join watermark existed and worked; the
synthesis simply wrote past the region it guarded.
