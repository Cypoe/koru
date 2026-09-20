---
type: belief
id: frag-a-branch-declares-its-payload-for-everyone
provenance: std/supervisor fold respell, corrected same-day 2026-09-21 — the
  generated step briefly carried an "args record" on void branches so a site
  could bind `| ok p` on `| ok`; deployed to the public post, then removed.
  Pinned by 320_167_supervised_void_branch_binding_refuses.
ts: 2026-09-21
tags: [koru, branches, payloads, transforms, supervisor, honesty]
---

# A branch declares its payload for everyone — transforms included (belief)

A `| name` in a tor's declaration is a public contract: every arm at every
site binds exactly what that line says — no more. A compile-time transform
may rewrite *how* dispatch happens (reroute the producing call, synthesize
a step tor, insert a fold), but it may not rewrite *what* a branch carries.
The generated vocabulary is the child's declaration, verbatim: a void
branch stays void through the fold, and `| ok p` on a `| ok` refuses with
the ordinary binding diagnostic (KORU101) exactly as it would without the
transform.

## The violation this corrects

The fold elaboration briefly did otherwise: it augmented each void step
branch with the attempt's *call-args record* so the site could bind `| ok p`
— "the arguments the winning attempt ran under." It compiled because the
shape checker runs *after* transforms and validated the binding against the
generated step's fabricated shape, not the child's declaration — the reader
of `dial`'s `| ok` saw a contract the toolchain itself violated invisibly.
This was the same class of lie as payload threading, laundered through
generated code: ambient inputs may be *read* by expressions (`port + 1` in
a re-entry arg reads the failed attempt's `port` — that is the reader
environment), but a binding is a declaration-level fact and may not be
invented.

The consequence discipline: this shipped to the public post within hours of
landing — a transform that fabricates payloads doesn't just accept a wrong
program, it *teaches* one. Removal was the only correct fix; no amount of
documenting the rule would have made the declaration stop lying.

## What is still legal

- Retry/counter state rides `__more` — the supervisor's own branch, which
  the transform *declares*. Synthesized state belongs on synthesized
  vocabulary, never smuggled onto the child's.
- A payload the producer declared (`| err i64`) binds and forwards
  normally through the fold — nothing about honest payloads changed.
- The enclosing tor's declared branch still bounds the forward: a site
  whose home declares `| refused i64` supervising a void `| refused`
  refuses ("carries nothing to forward") — the check that once consulted
  the augmentation now refuses unconditionally, because there is nothing
  left to consult.
