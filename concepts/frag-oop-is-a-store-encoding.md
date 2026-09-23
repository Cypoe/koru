---
type: belief
id: frag-oop-is-a-store-encoding
provenance: design walk 2026-09-22 (Lars + Devin) — "can we go full retard / import std/oop" — walked from "why is OOP bad" through "can an OOP program be encoded perfectly" to the dialect ruling. Guide lives at tests/regression/600_STDLIB/698_OOP/DESIGN.md.
ts: 2026-09-22
---

# OOP is a store encoding left implicit — and the rejections were the design (design belief)

**The thesis:** a heap is already a database. Object = row, class =
relation, reference = key, method = function over the row, dispatch =
which relation the key indexes. OOP invented no new computational object —
it invented a way to forget the object was a row. So `std/oop` adds no
capability; the substrate already computes everything OOP semantics
decomposes into. It adds a *spelling*.

**The encoding is unconditional at the semantic level.** Every OOP
behavior maps total (identity → stable handle, aliasing → shared handle,
override → most-derived arm, substitutability → row carrying named
fields). The empirical proof: every fast OOP runtime already performs
this encoding at runtime with guards and deopt — V8 hidden classes are
dynamically minted protos, HotSpot CHA rents the closed-world assumption,
monomorphic ICs pretend a call site is a single-store sweep. `.koop`
compiles to what the JITs approximate.

**The rejections were the design, not the absence of one.** Koru's "no"s
each severed a weld, and what remained standing is OOP's semantic core:
no `struct` (proto keeps affinity, kills the layout weld), no premature
concretization (layout is a consumer-chosen projection), no pointers
(handles/borrows, not free addresses), no constructors/`const`/`if`
(presence, immutability, branching — never welded to keywords). The
dialect inherits the discipline by omission; `if` in `.koop` is a
lowering, which is *why* it can exist.

**The law: allocation is a property of the plurality, never of the
element.** OOP's `new` fuses allocate + mint + initialize — the one
keyword that re-fuses all three welds. So `new X()` is legal only when X
declared its plurality (`herd Dog` → `Dog.all.insert`); a class with no
herd refuses — "objects are not allocated; rows are inserted." Per-element
growth already has its lawful home in `std/list` (allocator inside the
handle). A pointer-minting `alloc` is a demand-marker someday, never a
default door — a heap node is AoS and definitionally outside the reactive
substrate.

**`value` : `class` :: column : table.** The split OOP never made
(Valhalla took 25 years): values have copy semantics, no identity, and
inline into row columns; entities live in pluralities.

**The three real holes are one hole — openness.** Open-world dispatch,
per-instance shape, kind mutation: all degrade *only the dispatch column*,
never the data layout. The dialect refuses all three by default; the
refusals are features. What does NOT survive encoding and isn't a hole:
construction-order semantics, finalizers — dissolved, correctly, because
a perfect encoding preserves meaning, not the capacity for nonsense.

**The residual cost is ergonomic, not technical:** a dot-call surface
invites singular narration on a plural machine. The dialect must push
the plural face (`X.all` primary, handles secondary). Whether the
spelling earns its keep is decided by programs written in it.

**There is no file form — ruled on the walk (`.koop` dies).** A separate
grammar would have been a fifth weld; the OOP surface is a bundle of
declarations and `.k` already hosts those via transforms
(`std/store:new` precedent). `std/oop` is a `koru_std` transform module —
`herd`, `virtual`, `new`-as-teaching-diagnostic, method co-location —
possibly thin enough to be a pattern with one verb rather than a
language. OOP was never a language; it was a module's worth of sugar
over a table substrate nobody let exist. `new`'s absence is itself the
law: refusal-by-absence beats refusal-by-diagnostic.

**`std/oop` dissolved to zero — ruled on the walk.** The tree already
carries the substrate: union stores fold shared columns across
proto-typed members (690_274), the kind tag is synthesized (690_275),
methods are flows over row borrows, `new` is `insert`. The entire
residual is ONE feature in `std/proto`: **field-set extension**
(`std/proto(Dog : Animal)` = field-set union under the existing
name-sameness and cycle rules) — "compose the same concepts in data"
wearing its final name. Earned by maintenance (shared set declared once)
and protos outside union stores (`std/list:new(Dog)` needs the fields on
the entry). Substitutability is emergent: a Dog is an Animal when a
query over shared field names sees it; no `instanceof` — "in the union"
is the kind tag, "has the columns" is the query.

**Open:** the extension spelling (`:` in the arg vs a block-level form)
and whether even that clears the bar — decided by the first real
program that can't be honest with restated fields.

**Falsification:** a real program needing per-object heap identity or
genuinely open-world dispatch reopens the corresponding door — by demand
marker, program cited. If the lowered text is not compiler-accepted,
each gap is a `src/` defect, never a dialect reshape. If `.koop`
programs drift singular where sweeps were meant, the surface is a
reasoning regression and dies by its own hand.
