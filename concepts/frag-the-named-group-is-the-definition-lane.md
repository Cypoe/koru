---
type: belief
id: frag-the-named-group-is-the-definition-lane
provenance: ruled 2026-10-25 (Lars) during the destructure vocabulary ruling — "the destructure isn't just a destructure, it is a code-generation definition"
ts: 2026-10-25
---

# `name: { … }` turns the braces into a definition; bare `{ … }` projects (belief)

A destructure is two grammars, disambiguated **structurally** by what follows
`:` — never by content-sniffing a name:

- **Bare `{ … }` is a projection.** Entries are `path` or `local: path`.
  `:` means rename — the RHS is the defined symbol (a dotted path into the
  payload), the LHS the local name minted. The pun is the path's last
  segment (`{ pos.x }` binds `x`), and if you can pun you MUST pun —
  `{ x: pos.x }` is refused, write `{ pos.x }`. Matching is by name, never
  position.
- **`name: { … }` is a named group — a declared shape.** The name binds the
  whole payload AND the braces are a field list, not a projection:
  `ident`, `ident: Type`, `ident: { nested }` — the same grammar as a
  record declaration. `_:` discards the whole-bind and keeps the shape.

This is what makes `! each my:{ k, v }` mean more than `! each my` even when
`k`/`v` are the only fields: the `{ k, v }` is a **codegen-inspectable
definition**, not just a binding list. And it is where the schema lane lives:
`std/json:parse`'s `| ok _:{ name: string, addr: { city: string } }` reads
`DestructureField.type_text`/`.sub` — the old `name: Type` / `name: { sub }`
surface survives verbatim inside a named group.

## The ruling that produced it

`:` inside braces was overloaded three ways — descent (`{ pos: { x } }`),
alias-keep (`{ k: myk }` bound both), and type-ascription (`{ name: string }`
in schema arms). Lars ruled the flat form: `:` is rename only (`local: path`,
LHS local, RHS defined), descent becomes dotted paths (`{ pos.x }`), and the
type-ascription lane moves *outside* the braces — `name:{ }` re-declares the
shape instead of reinterpreting `:` inside it. The collision that forced it:
`name: name` inside braces is unreadable without knowing which side is the
field; the group prefix resolves it by putting the two `:` meanings in
structurally different positions.

## Pins

- `| entry e:{ k, v }` — whole + parts (`e`, `k`, `v` all bound).
- `| ok _:{ name: string, addr: { city: string } }` — schema arm (642_001–004).
- `{ pos.x }` pun (020_017), `{ user.x, x }` duplicate refusal (210_273),
  `{ x: pos.x }` must-pun refusal.
- Named groups skip projection checks: `destructure_named` on `Continuation`
  / `return_destructure_named` on `Invocation` — KORU036 (field existence)
  and KORU100 (unused leaf) do not apply to a declared shape.

## Open

- `! each` over maps: the projection set is the RHS path list — shape-driven
  emission can skip loads the handler never names.
- `parsed:{ name: string }` binds `parsed` AND the leaves — whether the
  whole-name should also auto-project (`parsed.name` reaching `name`) is
  settled as yes: both bind.
