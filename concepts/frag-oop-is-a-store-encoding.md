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

**`std/oop` dissolved to zero — ruled on the walk, landed same day.**
The tree already carries the substrate: per-proto stores pack the
proto's fields as root columns and `std/store:view` projects shared
leaves across member stores with `is`-narrowing (690_287) — the
closed-world polymorphic container. (Corrected at implementation: the
walk cited the sibling-member seed `{ player: Player, enemy: Enemy }`
(690_274/275) — that spelling is deliberately BROKEN, re-pinned to the
aspirational `std/store:set` + `kind` pool at 690_288-296; the live
surface is the view.) The residual — **field-set extension** — landed
as `std/proto(Dog <: Animal + Pet)`: parents merge before locals,
same-name+same-concept dedups, same-name+different-concept refuses,
cycles and unknown parents refuse, all pinned green at 698_001-009.
Substitutability is emergent: a Dog is an Animal when a view query
over shared leaf names sees it; "in the union" is the view's member
list, "has the columns" is the query.

**Spelling RULED and implemented:** transform args are OPAQUE TEXT —
split on top-level commas, brace-counted, never parsed as expressions
(corrected mid-walk: an earlier draft ranked candidates on parse-cost;
every spelling costs nothing). `Dog <: Animal + Pet` — the subtype
symbol verbatim, `+` as field-set union; multiple inheritance endorsed
(no MRO, no dominance — concepts compose or the declaration refuses).
`:` rejected on the labeled-arg convention; `->` reads "produces"; `is`
was the word-form runner-up. Implementation note: `:` DOES split at
arg-parse (label:value), so `Dog <: Animal` arrives as
name="Dog <", value="Animal" — every proto-door consumer extracts the
entry name as label-minus-'<'; six sites needed it (proto.kz,
list.free.kz, store.leaf.kz, store.kz, phantom_semantic_checker,
type_registry) — the rule now lives in a helper at each site.

**The reference gap (surfaced by this walk, shared with
frag-type-system-design's next-ranked item) — first rung landed:**
`owner: ref(Dog)` validates the target is a declared compound and
lowers to the i64 handle material in `std/list` element structs, the
target kept in proto metadata for checkers (698_006/007). Refs are
exempt from the containment-cycle walk (`next: ref(Node)` is legal by
design). In a store seed the column IS the handle — `ref()` there
refuses with the `i64` spelling named (698_009). Still open: `ref`
needs X's plurality to resolve *through* — no binder ties the handle to
its home store yet (`X.all` typable, not just sugar). Handles stay the
mechanism — generation-stable, checked-never-owned. Interior pointers
stay refused (swap-remove moves rows; references point at rows, never
cells). The walk didn't create this gap — object graphs made it
load-bearing.

**Open:** whether extension clears the bar — decided by the first real
program that can't be honest with restated fields; and whether the
blockless `std/proto(Cat <: Animal)` earns `?Source` support in the
transform wrapper codegen (today: explicit `{}`).

**Falsification:** a real program needing per-object heap identity or
genuinely open-world dispatch reopens the corresponding door — by demand
marker, program cited. If the lowered text is not compiler-accepted,
each gap is a `src/` defect, never a dialect reshape. If `.koop`
programs drift singular where sweeps were meant, the surface is a
reasoning regression and dies by its own hand.
