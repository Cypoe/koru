---
type: belief
id: frag-a-fields-typed-atoms-are-contract-premises
provenance: koru session — facet-fed claims: `i: i64 & >=0` on a tor field discharges a fold's base case and the produced-value bound; the emitter leaked `&` into Zig until the door learned to strip it
ts: 2026-10-29
tags: [koru, claims, facets, types, comptime, emission]
---

# A field's `&`-atoms are contract premises — the prover assumes them, the emitter strips them

A tor field's type text can carry `&`-atoms — `i: i64 & >=0`, or a
relational `& spend <= balance + margin` naming sibling fields. The
claims pass reads them as **premises, not checks**: the declaration *is*
the contract, so an arm that violates it is the arm's bug, and every
claim is judged conditional on the declared types being real. That is
the refinement-type reading — "proven when typed" — not a weakened one.

Two consequences fall out of the same reading:

- **At entry and in every meet.** Type rows join the fold-head meet
  (`honors` base: an open entry like `i: start` gives the prover only an
  equation; `i & >=0` is what pins the sign) and every back-edge meet.
- **Under substitution, they state the produced values' contract.**
  `i & >=0` read under `i' = i − 1` is `i' >= 0` — exactly the
  `terminates` bounded obligation, discharged by the type itself. A
  `!=` guard, which yields no rows at all, becomes *provable*: the
  candidate `i` and its boundedness both come from the field type, not
  the guard (675_019, outside-P the day before).

The honest boundary: an atom that is not one linear comparison
(`i: i64 & fizz`) is **outside-P naming the atom** — never silently
assumed (that would over-claim) and never silently dropped (that would
hide a malformed contract). `!=` atoms contribute no rows, which is
conservative and sound: under-assuming can only fail to prove.

The mirror obligation is emission. The same `.type` text reaches the
output emitter verbatim — `i: i64 & >=0` landed in generated Zig as a
field type and broke the build. `writeFieldType` is the single lowering
door; it now emits everything before the first `&` (as does the
handler-param write that bypasses it). Contract text rides the type
string for exactly one reason — so the claims pass can read it — and
must stop at the emission boundary.

Open edge: only the field-type position is wired. A `&`-atom on a branch
payload (`| live i64 & >=0`) parses and passes the same emit door, but
the claims fence does not read it — whether arm-side types join the
contract surface is a later ruling.
