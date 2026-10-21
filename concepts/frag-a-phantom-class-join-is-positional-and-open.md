---
type: belief
id: frag-a-phantom-class-join-is-positional-and-open
provenance: scoped-obligations worktree, 2026-10-17 — the `@` grammar was
  first landed commutative with a closed class dictionary, and two Lars
  rulings overturned both halves in one conversation: position decides
  role (name first, classes after), and the class vocabulary is open
  because an imported module is a compiler plugin
ts: 2026-10-17
tags: [koru, phantom, grammar, classes, obligations, ruling]
---

# A `@`-join is positional — name first, classes after — and the class vocabulary is open (belief)

The first landing of phantom classes treated `@` as an unordered join over a
closed dictionary: parts were classified by membership in a compiler-owned
class list, `scratch@scoped` ≡ `scoped@scratch`, and an unknown word after
`@` was a parse error. Both halves were wrong, and for the same reason:
the grammar had smuggled a classification problem into a place where
Koru already has a better answer.

**Position decides role.** `!` is edge-positional — `<!x>` consumes,
`<x!>` owes — and a commutative join has no edges, so `alloc!@scoped`
silently parsed as an identity literally named `alloc!` while
`alloc@scoped!` worked only by the accident of the `!` landing at the
string's end. One rule, two behaviours, chosen by which position the
name happened to occupy — not a grammar, a landmine. The fix is the
shape Koru uses everywhere else: the name holds position one, every
part after `@` is a class, and `!` binds the name atom — so
`alloc!@scoped` (a confined obligation) and `alloc!@scoped@view`
(name, debt, two joined classes) are valid, and the reversed spellings
refuse with teaching instead of canonicalising into nonsense.

**The vocabulary is open.** Rejecting an unknown class is a compiler
acting as the language's only arbiter, and that contradicts the
premise that an imported module is a compiler plugin. Classes are
indexed and carried on the binding; the compiler honours the ones it
knows (`scoped`), and any module — present or future — may read the
class set and attach its own semantics. A typo'd class silently fires
nothing, which is exactly what a typo'd state name already does: the
language's consistent answer, not a special case.

The deeper pattern: when a join relates *same-kind* atoms, order encodes
meaning; when it relates a name to its annotations, position decides
which is which — and the annotation vocabulary belongs to every
participant in the module graph, not to the compiler alone.

## Open questions

- Class order within the join is canonicalised (sorted) — classes are a
  set on one name, not a sequence. If a future class's semantics depend
  on join order, the rule "position carries name-vs-class, not
  class-vs-class" will need revisiting.
- `*` in class position is refused as a marker, not a class word; other
  marker characters (`!`, `:`) are refused by the same rule. Whether
  class words should accept a wider alphabet is undecided.
