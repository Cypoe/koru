---
type: belief
id: frag-std-refine-defines-facets-consumers-enforce
provenance: koru session 2026-09-15 — refine v1: proto-anchor meet, cross-home layering, confluent fold; 671_001..671_006 pin the semantics
ts: 2026-09-15
tags: [koru, stdlib, refine, proto, constraints, comptime, transforms]
---

# std/refine defines facets on abstracts; enforcement is the consumer's

`std/refine` is a **definition layer**, not an enforcer. Both `std/proto`
and `std/refine` live on abstract declarations — proto owns nominal
structure (`name: type` fields), refine owns predicate facets
(`name: type & bound…`) — and neither ever sees a concrete value. A value
becomes bound by a constraint exactly when it crosses a *consumer's*
boundary (`std/list:push`, `std/store` insert, `std/json` decode), so the
boundary is where enforcement lives. An unconsumed facet is enumerable
documentation, not a hole.

Mechanics, all library-level over existing machinery:

- `std/refine(Name)` resolves `Name` against the refining scope's home;
  `std/refine(home/path:Name)` addresses a declaration in another home —
  the qualified spelling rides the named-arg channel (`name=home/path`,
  `value=Name`, `had_explicit_label`), proto's own `app/alpha:Health`
  convention with no strings. Bare names are never a program-wide
  search — same rule proto uses for field references.
- The anchor is found in a live `std/proto` invocation OR its erased
  `// proto Name: …` marker, so dissolution order doesn't matter.
- Every refined field must exist on the anchor and its base must agree —
  a meet needs one base, not two.
- Multiple `std/refine` blocks — in the same module or layered across
  modules — fold onto one facet; whichever transform fires first emits the
  canonical `// refine home:Name: name: base & bounds` marker, later sites
  see the identical marker and dissolve. The meet is confluent by
  construction.
- Empty meets (`>20000 & <=1000`), unknown fields, base mismatches, and
  missing anchors all refuse at KORU205, naming the disagreement.

Layering is the reason refine is a separate module rather than `&` inside
proto's own grammar: a library declares `std/proto(Server)` plainly and a
downstream module tightens `port` without editing the library. Inline `&`
inside proto remains reachable later — proto could call refine's parser —
but the two spellings must meet the same facet.

Open rungs: consumer-side reads (the marker is the serialization; no
shared helper API is exported yet — the first enforcing consumer will
decide whether helpers ship as `pub` tors or an emitted namespace);
disjunction-with-default atoms; non-integer bases.

Pins: 671_001 (meet), 671_002 (empty meet refused), 671_003 (cross-home
layering), 671_004 (unknown field), 671_005 (base mismatch), 671_006
(confluent blocks).
