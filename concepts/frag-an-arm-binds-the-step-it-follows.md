---
type: belief
id: frag-an-arm-binds-the-step-it-follows
provenance: 690_367 pin → reattachArmsToLastStep moved `| row b` under a
  `|>` step written AFTER it; positional fix landed 2026-10-18
ts: 2026-10-18
---

# An arm binds the last step BEFORE it — attachment never reaches forward (belief)

An arm written at a `|>` chain's own level attaches to the last step before
it there; an arm written before every step keeps the head. "An arm attaches
to the last step at its own indentation level" (210_174) is read in source
order — position decides what the arm dispatches on, and the list as a
whole may never move an arm forward onto a step it precedes.

The order-blind reading compiled for months because every corpus shape put
arms after steps (`A` / `|> B` / `| arm`, the choke form). `insert
| row b |> X` `|> Y` at one level moved `| row b` UNDER `|> Y`, and Y's
tor took the blame — `'__store_write_s' has no branch 'row'`, a KORU021
naming the wrong party. The identical misfire fired against
`std/io:print.ln` — never a store defect at all.

Sibling of frag-pipeline-steps-own-their-deeper-arms (deeper-indented arms
bind the current chain tail): together they say an arm attaches to the tail
it visibly follows — deeper means that step's subtree, same level means the
last step it comes after.

What the correct tree then exposes: an unnamed `|>` on a branched tor is
the produce continuation, not a through. On inserth it IS the `row`
handler — `| row b` + `|>` is two claims on one produce (SHAPE002) — and on
a multi-branch tor it is ambiguous (KORU022 names the rule). There is no
"aligned with the arm means inside the arm": per-row work lives in the arm
body, one indent deeper.

Open: choke collection in tryDesugarChain is order-free by design — a
choke's reach is the whole lexical block — so an arm claiming a chain it
precedes is the same positional question, unmeasured.
