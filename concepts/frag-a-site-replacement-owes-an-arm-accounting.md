---
type: belief
id: frag-a-site-replacement-owes-an-arm-accounting
provenance: 699_021 session 2026-10 — 690_364's `| done` on a query site
  parsed, never ran, and no diagnostic said so; the same empty-carry
  replacement sat in rule and preorder
ts: 2026-10-14
tags: [koru, transforms, store, refusal, continuations]
---

# frag-a-site-replacement-owes-an-arm-accounting

A transform that replaces its site with something built from *selected*
continuations claims a vocabulary, whether it names one or not. Any named
arm outside that vocabulary evaporates: it parses as an ordinary branch,
the replacement is built without it, and the program compiles with a
branch that never runs. Silent mis-compile is worse than refusal — the
author wrote an obligation the compiler silently declined.

The audit belongs **at the point of replacement**, not upstream of it.
`SPlan.unclaimedArm` is called where the empty/selective carry happens —
query, rule, preorder each refuse `KORU161` naming the arm and the site's
claimed set. Putting it in the coordinator instead produced the wrong
blast radius: a refusal returned from `new`'s transform aborts the whole
store, and every downstream `insert` then reports a bogus `unknown store`.
A site refusal that only replaces the site keeps the store intact and the
mistake to one diagnostic.

The second half of that same lesson: when a refusal does kill a shared
emission, the "unknown store" follow-on is a *derived* lookup failure,
not a fact. `declarationRefused` exists for exactly this — check the
site's own verb prefix, not just `new`'s, so one mistake stays one error
(rule.kz/preorder.kz now check both).

Two structural corollaries:

- **Unnamed `|>` continuations are not arms.** `branch.len == 0` skips —
  profiler taps splice void-branch continuations onto sites and a naive
  census would refuse those (store.new.kz's own convention, reused).
- **The claimed set is per-site, not per-module.** query claims
  `! query`/`! first`/`| none`; rule claims `! row`; preorder claims
  `! preorder`. The audit takes the set as an argument — a shared helper
  hardcoding a vocabulary would be wrong the first time it ran on a
  second site.
