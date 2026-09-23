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

The consequence is sharper than the convenience: `std/oop` shrinks
toward zero. If a class is a proto + a store + flows co-located, and all
three already exist, the "language" is `herd` (proto+store minted in one
step), `virtual` (kind-column + switch synthesis), `new` (teaching
diagnostic — see catalog), and method co-location — **possibly thin
enough to be a pattern with one verb, not a language at all.** OOP was
never a language; it was a module's worth of sugar over a table
substrate nobody let exist.

Illustrative spelling — INVENTED, a design target; the `class`/`def`
block grammar is transform-owned, not parser grammar:

```koru
// animals.k — pure Koru, no new file form
import std/oop

std/oop:value(Point) { x: f64; y: f64 }    // a column type — no identity

std/proto(Animal) { hp: i64; pos: Point }  // an affinity, not a layout

std/oop:herd(Dog : Animal, 64) {           // proto composition + plural store
    def flee(dt: f64) {
        self.pos = self.pos + self.vel * dt;   // lowers to `stored`
    }
}
std/oop:herd(Cat : Animal, 64)

// the sweep — spelled however sweeps already spell:
std/store:query(Dog.all) ! d when d.hp < 10 |> flee(d, 0.016)
```

`new` needs no refusal rule in `.k` — the verb doesn't exist.
`std/oop:new(Dog)` may still be offered as the opt-in familiar spelling
that emits the teaching diagnostic, but refusal-by-absence is the
default and beats refusal-by-diagnostic: the law expressed as grammar.

| Spelling | Lowers to | Status of target |
|---|---|---|
| `class X { fields }` | `std/proto(X)` — affinity only | GROUNDED (665_PROTO) |
| `herd X : Y` | proto composition + plural store | GROUNDED (690_STORE) |
| `value V { fields }` | column type — inlines into rows | THESIS — proto-of-scalars today |
| `x.f()` | flow over `*X` — row borrow, static call | GROUNDED in spirit (query borrows) |
| `this.f = v` | `stored` — the one write path | GROUNDED — writes carry the cascade |
| `for (d : X.all)` | store sweep — the fused stripe | GROUNDED — the hottest loop we have |
| `static` members | singleton store | GROUNDED |
| `virtual`/`override` | `kind` column + closed-world switch | THESIS — cond+branches dissolved it |
| `interface` | row carrying named fields, checked point-to-point | GROUNDED direction |

## The rejection catalog (RULED — this is the guide)

**`new` does not exist — and the opt-in spelling enforces plurality.**
OOP's `new` fuses three acts the substrate deliberately split: allocate
storage, mint identity, run hidden initialization. In `.k` the rejection
is absence, not a diagnostic — there is simply no verb. The familiar
spelling may exist as a transform that *checks* the law:

    std/oop:new(Dog, hp: 10)    // Dog declared a herd → Dog.all.insert
    std/oop:new(Parser)         // error: Parser has no plurality.
                              // Objects are not allocated; rows are inserted.

The refusal is the teaching. Allocation is a property of the plurality,
never of the element.

**No pointer minting.** `std/oop:new` returning a heap pointer would
re-fuse the three acts AND mint an object definitionally outside the
reactive substrate: AoS, un-sweepable, writes that can't ride `stored`.
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
- If `.koop` programs consistently write singular flows where the sweep
  was meant, the surface is a reasoning regression regardless of layout
  — the dialect dies by its own hand.

## Status

**Residue.** No `input.kz` yet — the surface is honestly uninvented and
this document is the pin-seed. First artifact when built: the mock above
split into pins (declare, herd, sweep, virtual-dispatch, `new`-refusal,
value-vs-class), each `MUST_ERROR` or `MUST_RUN` against the lowering.
