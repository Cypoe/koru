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

What the correct tree then exposes, ruled 2026-10-18: an unnamed `|>` at a
step's own level, after that step's arms, is the step's JOIN — for every
tor, not only keyword ones (frag-the-unnamed-sibling-after-named-arms-is-a-join
now holds universally). The earlier reading — on a branched tor that `|>` is
the produce continuation, so `| row b` + `|>` is two claims on one produce
and a multi-branch tor is ambiguous — meant a failable verb mid-chain forced
either nesting the whole remainder one level deeper or turning failure into
a panic (koru-libs clay/tests/FLOW_BINDINGS.md §2). Only an unnamed `|>`
before any arm still means "continue on the sole success branch."

"Aligned with the arm" still never means "inside the arm": arm bindings are
arm-local and invisible at the join, so per-row work lives in the arm body,
one indent deeper. The accepted cost: the join makes "handle the failure arm
and carry on" the cheapest spelling — the no-fallbacks pressure that forced
nesting is gone, so that discipline now rides on authors and obligations.

Landed: KORU108 (400_213, 400_214) refuses a join or sibling-arm reference
to an arm binding — but only in CORE call arguments. Names inside library
syntax (`{{ }}` interpolation in 400_212, `stored {}` bodies in 690_367)
still fall to the host's undeclared-identifier error, as do names bound
nowhere at all; extending the refusal there is ruled
out of the core checker's reach — it must not know the library. (320_152 is
a different defect entirely: a VALID program the emitter mis-captures, not
an out-of-scope reference — an earlier draft of this paragraph folded it
into this hole, wrongly.)

Open: choke collection in tryDesugarChain is order-free by design — a
choke's reach is the whole lexical block — so an arm claiming a chain it
precedes is the same positional question, unmeasured.
