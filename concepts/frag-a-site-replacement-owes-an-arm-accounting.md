---
type: belief
id: frag-a-site-replacement-owes-an-arm-accounting
provenance: 699_021 session 2026-10 — 690_364's `| done` on a query site
  parsed, never ran, and no diagnostic said so; the same empty-carry
  replacement sat in rule and preorder; a 47-transform census found the
  same hole in constructor and capture
ts: 2026-10-14
evolved: 2026-10-21 — a replacement path added after the initial audit
  (the `!is_head_site` inline-splice return in store:query) shipped without
  `consumed_arms`; KORU183 caught it at test time. The declaration is owed
  on EVERY replacement return, including splice-only roads added later.
tags: [koru, transforms, store, refusal, continuations]
---

# frag-a-site-replacement-owes-an-arm-accounting

A transform that replaces its site with something built from *selected*
continuations claims a vocabulary, whether it names one or not. Any named
arm outside that vocabulary evaporates: it parses as an ordinary branch,
the replacement is built without it, and the program compiles with a
branch that never runs. Silent mis-compile is worse than refusal — the
author wrote an obligation the compiler silently declined.

**The declared `~tor` branch contract does not save you.** Transforms run
before the shape checker, and the checker only ever sees the *replacement*
— so `! construct *` / `| ?constructed *` on the tor is documentation, not
enforcement. Proven empirically: `| bogus` on `std/constructor` compiled
and ran. The claimed set must be audited inside the transform itself.

The audit belongs **at the point of replacement**, not upstream of it.
`ast_functional.unclaimedContinuation` is called where the
empty/selective carry happens — query, rule, preorder, constructor's two
terminals, and capture each refuse naming the arm and the site's claimed
set. Putting it in the coordinator instead produced the wrong blast
radius: a refusal returned from `new`'s transform aborts the whole store,
and every downstream `insert` then reports a bogus `unknown store`. A
site refusal that only replaces the site keeps the store intact and the
mistake to one diagnostic.

The second half of that same lesson: when a refusal does kill a shared
emission, the "unknown store" follow-on is a *derived* lookup failure,
not a fact. `declarationRefused` exists for exactly this — check the
site's own verb prefix, not just `new`'s, so one mistake stays one error
(rule.kz/preorder.kz now check both).

Census of the 47-proc transform surface (measured 2026-10-14): transforms
that carry `flow.body.continuations` through are safe by construction
(field's documented `| err` drop and kernel's fused `kernel` arm are
*intentional* consumption, not evaporation); sites whose arms are checked
against a declared table are safe (channel's join kinds, watch's field
names, pump's drained/step/live/wait, rings.new refusing all); open
vocabularies that stay arms are checked downstream (supervisor outcomes
vs the child's decl, regex match patterns). The evaporators were exactly
five: query, rule, preorder, constructor (both terminals), capture — all
now refuse. A generic post-transform arm-accounting pass remains the
deferred shape: the census says per-site audits suffice *today*, but only
because the surface was measured once; nothing structurally prevents the
next transform from reintroducing the hole.

**Update 2026-10-19 — the deferred shape landed.** The runner now audits
every transform write-back at the single splice point
(`auditArmAccounting` in transform_pass_runner.zig): the named
continuations on the input site must appear in the result's own
continuations (walked recursively, including `appended` items and
node-internal branch bodies) or in a new `SiteResult.consumed_arms`
field, else KORU183 refuses naming the transform, the arm, and the fix.
Consumption is a fact about the write-back, so it is declared on the
*return value* — not a static `~tor` annotation, which could never name
channel's join kinds or watch's field names because those are computed
from the decl's args at run time.

Three result kinds are exempt by construction, not by text-sniffing:
`is_refusal` items (a refusal IS the site's verdict — the arms die with
the site, they do not evaporate; the flag is set inside `ast.refusal` /
`refusalWithHint` and must also be set on hand-rolled verdict items),
appended-only results (the site is untouched), and `whole_program` (the
documented escape hatch, same license as the blast-radius bound). The
splice semantics *are* the accounting: `children: null` and
`retarget_producer` keep the site's continuations and count as carried;
a root-site `inline_code` node dissolves the flow and counts as a drop.

The first sweep it ran enumerated what per-site audits had missed:
`field` consumed `| field` as well as `| err`, `grid.sweep` consumed its
`! sweep` arm, `kernel:step`'s flatten consumed the `| step` arm-name,
`init` fused `| computed`/`| reduce` alongside `| kernel`, plural-store
`new` consumed lifecycle arms on a second return path, and three
test-local transforms hand-rolled verdicts without the flag. The
per-site audits stay — they fire first with the better diagnostic (they
name the claimed set and teach the fix); KORU183 is the floor under
transforms that did not audit, and it is what makes the bug class
unable to re-enter silently.

Two structural corollaries:

- **Unnamed `|>` continuations are not arms.** `branch.len == 0` skips —
  profiler taps splice void-branch continuations onto sites and a naive
  census would refuse those (store.new.kz's own convention, reused).
- **The claimed set is per-site, not per-module.** query claims
  `! query`/`! first`/`| none`; rule claims `! row`; preorder claims
  `! preorder`; constructor:value claims `! construct`/`| constructed`
  while constructor:struct claims `! construct` alone. The audit takes
  the set as an argument — a shared helper hardcoding a vocabulary would
  be wrong the first time it ran on a second site.

**Every replacement return owes the declaration.** The first audit
covered the returns that existed that day; the `!is_head_site`
inline-splice return in `store:query` was added later, spliced the loop
without the arm set, and compiled — KORU183 is what caught it
(115_043/044, nested site-view flows across a module boundary). An
accounting declared on most returns is no accounting: each new
`.transformed` return that drops named arms is a fresh hole until it
declares `consumed_arms`.
