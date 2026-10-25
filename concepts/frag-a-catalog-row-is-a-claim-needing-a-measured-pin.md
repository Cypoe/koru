---
type: belief
id: frag-a-catalog-row-is-a-claim-needing-a-measured-pin
provenance: the std/target catalog grew a `construct` verb whose `"supported"` rows name which surface constructs a target lane answers; the gate asked who ruled those spellings
ts: 2026-10-25
---

# A catalog row is a claim, and a claim needs a measured pin

`std/target`'s `construct(c)` row is the C lane's declared coverage: a
`"std/store:take": "supported"` entry asserts the lane lowers that surface
construct. That assertion is a claim like any other in the tree — it is
ruled only when a regression pin measures it.

The ruling, decided with the provenance rung it landed on:

- **`@from_construct("std/<mod>:<verb>")` is the ruled internal mark** a
  transform stamps on an invocation it mints, so the emit walk can ask the
  catalog by the surface key after the surface name has been lowered away.
  It is pass-internal metadata (`.marks`), never authorable surface syntax,
  and must never appear in emitted host text.
- **A stamp is provenance, not a claim.** A transform whose construct has
  no C-pinned regression still stamps its mint — but the catalog carries no
  row for it. That is the designed dormant state: the walk reports the
  unclaimed ask, the catalog claims nothing.
- **A `"supported"` row is added only with the pin that measured it.**
  Current pins: `stored` 690_001/010, `insert` 690_011/022/043,
  `watch` 690_001, `take`/`query` 690_070 + 690_075, `rule` 690_336.
  `stripe` and `preorder` are stamped and deliberately rowless — no C test
  exercises them yet.

Resolved open question (the splice vocabulary was unnecessary): on the
C lane `watch` does not tap-splice at all — `store.new.kz` mints one
`__store_watch_<s>_<f>_<ord>` event per arm, and the impl flow's head is
the arm's own call. Provenance lands on a cloned stamp of that head, so
the walk sees the site once `impl_of` flows are descended (they emit
through their event; the emitter's skip is only its standalone-flow
enumeration). The stamp answers why the site exists; the head's own
std-qualified name still answers what it emits — both are asked.

Evolved on the builtin-solver rung: `builtin(c)` rows stopped being
`"lowered"` statuses and became claims with three shapes — a `{1}`/`{2}`
template *is* the declared lowering, a `rule:<arm>` value names an
emitter-owned rule the catalog explicitly delegates, and `"refused"` is
the boundary as data. The emitter asks the catalog first
(`diag.resolve_builtin`) and applies the template verbatim; a template is
pinned by dual-answer — the emitter still runs the legacy arm into
scratch and drift-logs any byte mismatch, so the row cannot diverge
from the oracle it replaced without leaving an artifact. Unrowed
builtins still hit the arms unchanged; an absent catalog disables the
whole consult. The delegation shape matters: `rule:as` declares *that* an
arm owns `@as`, not *what* it emits — bounds checks stay semantic, not
spelling.
