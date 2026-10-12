---
type: belief
id: frag-c-widening-mass-sits-in-the-compiler
provenance: c-lane census run over tests/regression at ccomp d237bf4ff,
  2026-10-12 — docs/c-lane-census.md holds the numbers
ts: 2026-10-12
tags: [koru, verification, c-lane, templates, transforms, census]
---

# frag-c-widening-mass-sits-in-the-compiler

Widening the C fragment is work on the compiler's own machinery — its
transform/template procs and synthesized bodies — not on user-authored
`|c` impls.

The test plan predicted the dominant refusal row would be user-side:
"every `std/io` call until `|c` impls exist." The measured corpus says
otherwise. The two walls carrying the mass are `no-c-template` (330 —
a `[template]` tor invoked without a `|c` variant, refused as KORU121
before the emitter ever runs) and `raw host lines` (326 — by-design
refusal). Of the `NoCProcBody` class, the biggest single cluster is
`__store_insert_*` — procs the *store transform synthesizes*, which a
user can never write a `|c` body for.

Two durable consequences:

- The `|c` ordering is template-first: `~for` (155 dirs) and `~if` (122)
  carry 84% of the template wall. Widening = writing `[template] proc
  for|c` / `if|c` / `const|c` bodies and teaching transforms to emit
  `|c` variants of their synthesized procs — compiler work, not a user
  migration.
- KORU121 belongs to the refusal census even though it fires upstream
  of the C emitter: it is the coverage instrument's "no `|c` template"
  row by another code. An instrument that only counts KORU047
  under-reports the true wall by a fifth.

Open: whether `effect arms` (163) splits cleanly into `~for`-governed
transplants (eligible once `for|c` exists) versus genuine resumables —
the census counts them together today.
