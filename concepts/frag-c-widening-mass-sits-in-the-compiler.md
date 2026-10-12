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

Open (resolved 2026-10-12): the `effect arms` class DOES split cleanly —
`!` under a parent carrying `inline_body` is transplant vocabulary; the
census now walks past it and genuine resumables still refuse (400_209
holds). Session 4 measured the prediction out: `for|c`/`if|c`/`const|c`
plus the marker resolver landed, and the `~for`/`~if` `no-c-template`
wall went 277 → 0 in one tranche — with only 13 dirs newly emitted,
because the same dirs carried the *other* measured axes. The widening
thesis holds harder than predicted: the next wall for the prime sieve
is again compiler-side — `grid.stored` synthesizes `__grid_write_*`
procs with `.target = "zig"` unconditionally, and their bodies are
lowered through `grid_read.lower` into Zig spellings. The store/grid
synthesis tranche is the same kind of work one layer down: not user
`|c` impls, but transforms minting `|c` variants of the procs they
synthesize.

Resolved 2026-10-12 (session 5): the prediction held one layer down.
`grid.new`/`grid.stored`/`grid.sweep`/`store.new` now mint `|c`
variants of their synthesized units, and `2105_prime_sieve` — the
flagship cell — runs `zig c` byte-identical (`78498`, ccomp
`-fstruct-passing`). The wall that looked like "users need |c impls"
was, again, transforms stamping zig on the compilers


Resolved 2026-10-12 (session 5): the prediction held one layer down.
`grid.new`/`grid.stored`/`grid.sweep`/`store.new` now mint `|c`
variants of their synthesized units, and `2105_prime_sieve` — the
flagship cell — runs `zig c` byte-identical (`78498`, ccomp
`-fstruct-passing`). The wall that looked like "users need |c impls"
was, again, transforms stamping zig on the compiler's own output. The
remaining mass is the same shape one more layer down: plural stores,
watches/guards, row-layout grids.
