---
type: belief
id: frag-resource-tokens-are-minted-not-named
provenance: kopium opaque-handles ruling 2026-09-07/08, carried to
  interpreter.pool.kz 2026-10-20
ts: 2026-10-20
tags: [koru, kopium, obligations, custody, pool, handles]
---

# A resource token is minted, never named — the sequence was custody you could count (belief)

`HandlePool.mintResourceToken` used to mint `h:{type}:{counter}` —
`h:Connection:1`, `h:Res:2`. The text was honest and legible, and it was
also a custody oracle: a program that counted mints could *spell* a live
handle it was never handed. `grab(r: "h:Res:1")` resolved. Possession
enforcement — "does this token name something the pool holds" — can only
refuse what was never minted; it cannot refuse a guess that happens to be
right. The pool now mints `h:{type}:{seeded six-hex}` (per-pool seed from
`std.crypto.random`, splitmix avalanche over seed+counter, collision
retry among live tokens). `h:Type:` stays for legibility; the suffix is
unpredictable, so the old sequence is a fabrication like any other and
the refusal path is uniform: spelled text that names nothing held is a
guess, refused.

The rule this carries, already ruled for notes handles: **binding is the
only legal access.** A verb's return mints the token; the `rN` the report
binds is what later turns spell — `grab(r: r1)` resolves because the
bridge holds the binding, not because the text is knowable. Provenance
(minting event, scope, bridge, dependencies) lives *on* the Handle
record, not in the token text; the token is an identity, not a receipt.

Two consequences the implementation surfaced:

- **Regression pins can't quote minted text.** `440_050` used to expect
  `h:Res:1` in output; under a seeded mint the bytes differ per run, so
  the pin now asserts *behavior* (bind resolves, spelled guesses refuse,
  spent refuses) and only prints refusal text that quotes tokens the
  file itself spelled.
- **`rN` bindings outlive the token's usefulness.** After `release`, the
  binding still maps to spent text — the refusal is the same "names
  nothing the session holds" as a fabrication. Spend and guess are
  indistinguishable at the wall, which is correct: both are programs
  naming custody they don't currently hold.
