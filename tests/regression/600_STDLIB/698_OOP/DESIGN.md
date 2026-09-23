# std/oop — OOP as a store encoding, made explicit (design walk residue, 2026-09-22)

> **DELETE-WHEN-PINNED.** This document is interim scaffolding from a design
> walk (Lars + Devin). Its entire intent migrates into pins in this cluster;
> when the pins carry it, this file dies. Tests are the spec; prose drifts.
> Every claim below is stamped: **GROUNDED** (a test/file/belief read during
> the walk proves the substrate exists), **RULED** (Lars ratified it on the
> walk), **THESIS** (we believe it, nobody has attacked it), **OPEN** (genuine
> undecided design question).
>
> The things we reject are sometimes better than the things we adopt. The
> rejection catalog below is the load-bearing section — the adopted surface
> is the smaller half of this document.

## The thesis (THESIS, attacked twice on the walk and it held)

**OOP is a store encoding left implicit.** A heap is already a database:
an object is a tuple, a class is a relation, a reference is a key, a
method is a function over the row, dynamic dispatch is "which relation
does this key index." OOP never invented a new computational object — it
invented a way to forget the object was a row, replacing table identity
with a bare pointer and paying for the amnesia forever.

So `std/oop` adds **no capability**. The substrate already computes
everything OOP semantics decomposes into. It adds a *spelling* — and the
encoding direction finally runs honest: class declares the table, method
declares the flow, dispatch is a switch the compiler sees every arm of.

**The industry's proof (THESIS, strong):** every fast OOP runtime already
performs this encoding at runtime, badly, with guards and bailouts — V8
hidden classes are protos minted dynamically, HotSpot's CHA +
devirtualization rents the closed-world assumption, monomorphic inline
caches pretend a call site is a single-store sweep. Making OOP fast was
always "secretly convert it to stores." `.koop` compiles to what the JITs
are approximating — statically, without deopt.

## The four welds — what was actually bad (RULED as diagnosis)

OOP's syntax is innocent. The disease is four orthogonal ideas welded:

1. **Object = atom of allocation AND atom of code organization.** Fields
   behind `this` → AoS with per-object headers; the unit you think in
   becomes the unit the compiler must lay out.
2. **Open-world dispatch keyed on identity.** `x.f()` = unknown code via
   a vptr in every header — a layout tax (prefix-compatible layouts
   forever) plus an unanalyzable call graph.
3. **Inheritance = field reuse + substitutability + implementation
   reuse** in one keyword.
4. **Encapsulation that hides from the compiler** — indirection as the
   enforcement mechanism, paid in cache misses.

Every "no" Koru already said — no `struct`, no pointers, no constructors,
no `const`, no `if` — severed one of these welds, not the idea. The
rejections were the design; see the catalog.

## The adopted surface (THESIS — spelling, all invented)

**RULED 2026-09-22 (same walk, later): there is no `.koop` file form.**
A separate grammar would have been the fifth weld — the OOP surface is a
bundle of declarations, and `.k` already hosts those. `std/oop` is a
transform module in `koru_std`, spelled inside ordinary `.k` files —
the same relationship `std/store:new` has to the parser. The comptime
text-reader dies with the file form (nothing left to read); the belief
it was going to prove — declarations are library-minted — is proven by
the module itself existing.

**RULED 2026-09-22 (same walk, later still): `std/oop` the module
dissolves to zero.** The tree already carries the polymorphic substrate
under other names: union stores fold shared columns across proto-typed
members (690_274), the kind tag is synthesized (690_275, prefigured
690_273), methods are flows over row borrows, `new` is `insert`. A union
store IS the closed-world polymorphic container — every kind visible at
comptime, shared fields deduped by name-sameness, the kind tag as the
dispatch column. OOP's "treat all Animals uniformly" is a sweep over the
union; per-kind behavior is `when`-arms. The vtable is a column.

The entire residual is **one feature, and it lives in `std/proto`:
field-set extension** — `std/proto(Dog < Animal)` = Dog's field set is
Animal's ∪ its own block, checked by the same rules (same name + same
concept dedups; same name + different concept refuses; cycles reject
through the existing `findCycle`). This is the already-ruled direction —
"compose the same concepts in data, never in behavior" — wearing its
final name. Extension earns its keep on maintenance (declare the shared
set once) and on protos outside union stores (`std/list:new(Dog)` needs
Dog's entry to really carry the fields).

Substitutability needs no declaration: a Dog is an Animal precisely when
a query over shared field names sees it — structural, checked by the
fold. No `instanceof`; "is it in the union" is the kind tag, "does it
have the columns" is the query.

### The extension spelling — a micro-language inside the arg (OPEN)

Transform args arrive as **AST, not values** — the transform owns the
interpretation, so the extension operator lives only inside proto's arg
and reserves nothing language-wide. Candidates walked:

- `Dog : Animal` — parses today as a *labeled arg* (`capacity: 64` is
  the same grammar). Semantically defensible (type ascription,
  `x : T` = "x is a T") but syntactically misleading in Koru and blocks
  a real label named `Dog`. Rejected on collision.
- `Dog < Animal` — parses today as a comparison AST; `<:` is the
  subtype symbol in type theory (`A <: B` = "A is a subtype of B"), so
  the operator is *correct*, not merely available. Zero grammar work.
- `Dog is Animal` — most readable, but `is` is no keyword/operator
  anywhere in the lexer: it costs new grammar for aesthetics.
- `Dog -> Animal` — `->` already means "produces/returns" (arm arrows,
  return types); "Dog produces Animal" actively lies. Rejected.

Leaning `<`, pending Lars. The arg grows a small field-set algebra with
no new grammar: `Dog < Animal + Pet` (multiple extension — `+` as
set-union, the diamond resolving by name-sameness or refusing). `-`
(exclusion) is parked as demand-marker — power that invents complexity
nobody asked for.

Illustrative spelling — INVENTED, a design target:

```koru
// animals.k — pure Koru; everything here exists except `:` extension
import std/proto
import std/store

std/proto(Animal) { hp: i64 }

std/proto(Dog < Animal) {        // THE missing piece — field-set union
    barked: bool
}
std/proto(Cat < Animal)

std/store:new(animals, capacity: 64) { dog: Dog, cat: Cat }

std/store:insert(animals) { hp: 10, barked: false }
std/store:query(animals)
! query a when a.hp < 10 |> std/io:print.ln("{{ a.hp:d }}")
```

| OOP want | Where it lives | Status |
|---|---|---|
| `class X { fields }` | `std/proto(X)` | GROUNDED (665_PROTO) |
| `X extends Y` | `std/proto(X < Y)` — field-set union | **THE GAP** — everything else exists |
| polymorphic collection | union store, folded columns | GROUNDED (690_274) |
| `virtual`/`override` | synthesized kind tag + `when` arms | GROUNDED (690_275) |
| `x.f()` | `x \|> f` / flow over `*X` | GROUNDED |
| `this.f = v` | `stored` — the one write path | GROUNDED — carries the cascade |
| `for (x : Xs)` | store sweep — the fused stripe | GROUNDED |
| `static` members | singleton store | GROUNDED |
| `new` | `std/store:insert` | GROUNDED by absence |
| `value V` | `std/proto(V)` | GROUNDED |
| `instanceof` | kind tag / column presence | GROUNDED — structural, not declared |

## The rejection catalog (RULED — this is the guide)

**`new` does not exist.** OOP's `new` fuses three acts the substrate
deliberately split: allocate storage, mint identity, run hidden
initialization. In `.k` the rejection is absence, not a diagnostic —
`std/store:insert(animals) { hp: 10 }` is the whole verb, and the
plurality it lands in is always named at the call. There is no path that
mints an object without declaring where it lives. Refusal-by-absence
beats refusal-by-diagnostic: the law expressed as grammar. Allocation
is a property of the plurality, never of the element.

**No pointer minting.** A heap-allocating verb would re-fuse the three
acts AND mint an object definitionally outside the reactive substrate:
AoS, un-sweepable, writes that can't ride `stored`.
The one legitimate per-element allocation trigger already has a home —
growth lives in `std/list`, allocator inside the handle. "Heap object" =
list element; identity = index/handle. A true `alloc` is a demand-marker
someday (irregular heterogeneous graphs), never a default door.

**`value` : `class` :: column : table.** The split OOP never made
(Valhalla needed 25 years): `Point` was never an object. Value types have
copy semantics, no identity, and inline into row columns for free.
Entities live in pluralities. Two keywords, day one.

**Open world refused.** Runtime class introduction / monkey patching /
`become:` kills the closed switch. Even then only *dispatch* degrades
(to a function-pointer column) — data stays dense. But the dialect does
not open it: the world is closed, the switch is total, exhaustiveness is
checkable.

**Per-instance shape refused.** JS-style property bags need an EAV
table; not the dialect's problem. Classes declare fixed field sets.

**Kind mutation refused.** An object changing class is take+insert
between stores; no cheap spelling offered.

**Constructors dissolved, not encoded.** Fields forced by declaration;
no hidden control flow, no construction-order semantics, no
virtual-during-construction — the problem class vanishes.

**Diamond refused, not resolved.** Two protos naming the same field
different types collide loudly under name-only sameness.

**`private` already exists.** Module-private tors; layout is never
hidden because there is no object boundary to hide behind —
encapsulation becomes structural: no write exists that bypasses the
write path.

## The residual cost (OPEN — the honest hole)

The encoding is perfect; the **writing style it invites** is the cost.
A dot-call surface pulls a writer toward singular narration on a plural
machine — `dog.owner.house.heat()` instead of the sweep. The dialect
should push the plural: `Dog.all` as the primary face, singular handles
as the secondary. Whether the spelled surface earns its keep is decided
by writing real programs in it, not by argument.

## Falsification conditions (written before pressure arrives)

- A real program that cannot be expressed without per-object heap
  identity reopens the `alloc` door — by demand marker, with the program
  cited.
- A program whose performance *requires* open-world dispatch reopens
  the closed-world ruling — with the same burden.
- If the lowered text is *not* something the compiler already accepts,
  each named gap becomes a compiler defect to fix in `src/` — never a
  reason to shape the dialect around the gap.
- If OOP-shaped `.k` programs consistently write singular flows where
  the sweep was meant, the *pattern* is a reasoning regression regardless
  of layout — and then even the doc entry dies, not just the module.

## Status

**Residue.** No `input.kz` yet. The walk's arc: `.koop` file form →
`std/oop` transform module → **one missing feature in `std/proto`**:
field-set extension (`X < Y`, spelling leaning `<`). First pins when built: extension flattens
parent fields (MUST_RUN), same-name-different-type refuses (MUST_ERROR),
extension cycles refuse (MUST_ERROR via `findCycle`), extended proto
feeds `std/list:new` and a union store (MUST_RUN). The pattern half —
"OOP-shaped programs are protos + union stores + flows" — needs no code;
it may want a `koru-by-example`-style doc entry, not a cluster.
