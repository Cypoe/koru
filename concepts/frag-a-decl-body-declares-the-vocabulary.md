---
type: belief
id: frag-a-decl-body-declares-the-vocabulary
provenance: std/rings + std/channel surface ruling, 2026-09-24 — the
  declaration-head question resolved not by picking a spelling but by
  recognizing the grammar the decl bodies already shared
ts: 2026-09-24
tags: [koru, std, declarations, vocabulary, grammar, surface, ruling]
---

# A `std/` decl's `{ }` body declares the vocabulary — the construct decides the algebra (belief)

A `{ name: Type }` body on a `std/` declaration is one grammar — the
proto-definition shape — parsed by `struct_literal.parseFields`. What the
entries *mean* is the construct's algebra:

- `std/proto(R) { id: u64 }` — a *product*: fields coexist in one struct.
- `std/store:new(g) { hp: i64 }` — *columns*: a SoA projection; `!` arms
  name them.
- `std/rings:new(f, capacity: N) { value: u64 }` — *degenerate*: exactly
  one entry, the element shape.
- `std/channel:new(i, capacity: N) { reading: Reading, alert: Alert }` —
  a *sum*: each entry is one kind — one lane, one arm word, one payload
  proto.

The consequences the ruling carries: **arm names are authored, not
derived** — `{ frame: Packet }` fires `! frame`; `reading: Reading`
fires `! reading` only because that is the declared word. Multi-kind
needs no new grammar — it is the field list. Scalars collapse the same
way protos do (`{ value: u64 }` is a legal element — a proto is a struct,
a scalar is the degenerate word). `*`/`[N]`/phantom-typed entries refuse:
a slot holds plain values by copy, and `*` already means *borrowed*.

Two enforcement facts the compiler contributed to the ruling:
`struct_literal` requires commas between entries (a newline-separated
second field is a missing-comma teaching refusal, not a second kind), and
the pun law refuses a second bare positional — so a verb's value rides a
`v:` label (`send(inbox, v: r)`), the `std/list:push` convention.

Measured: `std/supervisor`'s fold attaches to a ring's `| full`/`| none`
void arms through same-module wrapper tors (320_110–112) — status arms
are vocabulary, not types, so policy composes without either construct
knowing the other. Boundaries found by refusal, not assumed: v1
supervises same-module children only (KORU161; 320_113 OWED), and `|
retry` re-entry targets the *same* event with remapped args — the
explicit form changes arguments, not targets.

## Open

Whether `supervised` reaches cross-module children (the ring/channel
verbs themselves) is the owed seam. If channel lane emission or ring ops
ever expose same-module generated tors, 320_113 flips without a grammar
change.
