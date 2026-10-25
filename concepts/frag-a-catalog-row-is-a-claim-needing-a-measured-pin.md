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

Open questions: `watch` lowers into tap-spliced code — no surviving
invocation carries its stamp, so its provenance is latent until the walk
grows a path that sees splices. Whether that wants a stamp of its own or a
different provenance shape is undecided.
