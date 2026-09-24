---
type: belief
id: frag-std-store-design
provenance: introduced by 24d782f1 — test(pin): std/store design cluster — 690_STORE born (8 aspirational pins + DESIGN.md), 2 green substrate pins
ts: 2026-07-04
---

# std/store — compiled-reactivity application state (design belief)

Application state in Koru is a **store**: a comptime-named, second-class,
plurality-native table whose only write path is `stored{}` and whose
subscriptions are **compiled into the write path** (tap-transplant
machinery, producer owns the guard) — never registered at runtime. The
design walk of 2026-07-04 established, across two adversarial gauntlets
and three hostile showcase programs, that this spine holds:

- One centralizing write-subflow per store (ruled f) hosts everything:
  spliced watches/interceptors, the atomicity lock, DI'd backend arms.
- One lvalue path grammar, four addressing heads (handle / declared key /
  query-row / elided singleton); positional index is never identity.
- CRUD lifecycle events (`inserted`/`updated`/`removed`) are the single
  primitive; maintained aggregates are the planner compiling queries into
  the same interceptor branches; `take` = `removed` + a store-named
  phantom obligation (a taken row cannot leak).
- Layout is the closure of the queries (projections → SoA columns,
  predicates → maintained views) — and NO ARCHETYPES: capability is data,
  the fused stripe replaces per-system iteration (one corpus read serves
  the whole workload; ruled O13).
- Writes interleave, never overlap: write + full cascade is the atomicity
  unit; the chain is the envelope lean covers multi-write grouping.

**That line was not implemented, and the gap cost 2x (2026-08-03).** The
multi-field envelope emitted one write call PER FIELD, in written order, each
carrying the whole row's payload with typed zeros in the slots it was not
writing. So the block was a sequence, not a transaction: a later entry read what
an earlier one had already landed, which is writes overlapping — the exact thing
the line forbids. It had been pinned GREEN as though it were the ruling, and a
second test was then written to exploit it.

The fix is to make the envelope what its name says: ONE call carrying every
value. Arguments are evaluated before a call, so pre-state semantics falls out
with no analysis, and N-1 calls per block disappear.

**The correctness bug and the performance bug were the same bug.** Column-routed
per-row work in the ECS benchmark roughly halved on the fix alone — boids went
from 1.2x slower than a hand-written striped Zig baseline to 1.6x faster, with a
bit-identical checksum before and after. That is the durable part: the design's
atomicity requirement was not a constraint the implementation was paying for, it
was the faster implementation, and diverging from it was the tax. When a spine
line looks like it costs something, check whether it has been implemented before
believing the cost is real.


**Rung one is BUILT and green (2026-07-05, branch `store`):** the (f)
subflow is real — `create` coordinates, appending per store the typed
cell, an apply event/proc announcing the written field as a terminal
branch (`{old,new}` payload usage-synthesized per the (c) lean), and the
write event implemented by a generated flow whose arms are the
transplanted interceptor+watch branches. This is the first
transform-minted callable with a Koru-level body in the compiler; the
cross-store cascade is ordinary calls through generated subflows.
Transplant purity (ruling a) is enforced at rewrite time with a
koru-level diagnostic. 690_001-004 run green; 690_006 rejects as
designed.

Key substrate facts flipped during the walk: the multi-cell capture
routing believed to be a RED frontier (320_036's own header) already
passes; boolean connectives in when-guards existed in the parser but were
never once exercised by the corpus until 020_036 pinned them green.
Implementation added one more: cloneContinuation's documented shallow
expression/source-pointer footgun bites for real — a transform rewriting
cloned bodies must swap in fresh structs or it mutates the original tree.
And the ecs-store gap analysis (2026-07-05) added a fourth: rung one's
non-i64 column wall is **scoping, not architecture** — kernel:shape
declares f64 fields green in the corpus (390_001) through the same
transform substrate store.kz uses, so compound columns (f32/vec3/mat4x4,
pin 690_020) are extension work, not invention.

**Rung two started (2026-07-05, branch store-rung-two): plurality is
real.** Bare-type seed fields (`hp: i64`) declare a PLURAL store — SoA
column arrays + len, insert/inserth (handle branch), per-query
qrow/qbody/qsweep units keyed by SOURCE LINE (transform order can never
skew unit numbering), row-addressed apply/write subflow, take
(swap-remove). Two load-bearing mechanisms: standing query enters carry
the insert site's `__site_line` as a comptime arg, so a query only hears
inserts below it in source (690_005 fires on insert, 690_008 sweeps
pre-existing rows instead of double-firing); and generated |zig procs
call generated events directly (`main_module.<n>_event.handler(.{...})`)
— which met dead_strip's koru-visible-only reachability model and was
answered by the designed `retain` annotation, not a workaround. The
parser now accepts dotted paths as destructure field names (ruling 6's
projection grammar; PARSE001 loosened per the maximalist tenet).
690_005 GREEN.

**Rung two grew five more greens (2026-07-05 late):** take obligations
(`<store-item!>` on the `| item` identity payload — Field.phantom, the
660_027 pattern; KORU030 now says "obligation" by name), UPDATE WHERE
(indexed lvalue head `store[row].field`; site-replacement transforms
preserve impl_of because a query body's head IS an impl flow's head),
multi-watch fan-out in source order, declared capacity with `| full`
exhaustion-as-a-branch, and T2's cascade-cycle rejection. The cycle
graph is **FIELD-level, not store-level** — the store-level version
false-positived on 690_004's same-store hp→shield derivation (caught as
a regression, reworked same session). Walker fact overturned: nested
`stored` sites transform BEFORE their enclosing create's head fires, so
coordination-time scans must read both spellings of a write (raw
`std/store:stored` and rewritten `__store_write_*`). 690 board:
11/11 runnable green, 9 TODO.

**And two more (2026-07-05, later still): stripe + the cross-store
reactive closure.** `stripe(store)` is real — announce-only re-dispatch
(peek proc reads CURRENT values, the announce subflow re-fires the same
watch arms; no write, so interceptors correctly do NOT run). And
690_013 closed the gauntlet's headline hole ("the filter tab that does
nothing"): a watch guarded on ANOTHER store's field splices an
announce-call into that store's write path, so writing `ui.mode` re-
evaluates game's guarded watch — level-trigger on write; edge-trigger
dedup stays undesigned. Emitter root-fix along the way: an empty
terminal arm in the expression path now emits `{}` instead of NOTHING
(`.mode => ,` was a Zig parse error). 690 board: 13/13 runnable green.

**And the splice is plurality-aware (2026-09-07, 690_340).** The
foreign-guard announce-call is field-only only while the TARGET is a
singleton. A plural target's announce is `(row, field)` and a foreign
write names no row, so the step instead calls a synthesized
`__store_announce_each_<T>(field)` — an event whose impl loops the
target's live rows calling its own announce per row. Writing
`board.alarm` under a `when board.alarm == 1` watch on a 64-row store
re-fires 56 watch evaluations after 8 rows were culled — live rows,
not capacity. Owned-column stores still get no announce path at all
(their `| item` discharge rules out the bundled envelope that hosts
it), so a guarded watch there remains unexpressible — refused by
absence, not by diagnostic.

**The rung-two sweep total (2026-07-05 night): the runnable 690 board
went 8/20 → 15/21.** Chain envelope (write-all-then-announce-all — the
(i) lean executable; envwrite is the write-only half, announce the
dispatch half, so watches observe settled multi-field state), and f64
scalar columns (690_021, tier 1 of 690_020 — uniform-type singletons;
value-type threads through apply/write/envwrite/peek). Four pins stay
TODO with their walls named in-file: (k)-disposal gates 015/016, T8
design gates 017, whole-program rewrite gates 018's rvalue key paths,
rung-3 planner gates 019.

**The perf instrument (2026-07-05):** ecs_bench_suite's seven workloads
are mapped as the store's honest-ABSENT benchmark battery
(`koru-benchmarks/suites/ecs-store` — board, provenance, M2 Pro criterion
baselines of six reference engines). Three one-to-one ballparks
(simple_iter's ~3.3µs legion sweep is O13's falsifier bar), two
dissolved-by-design entries validating NO-ARCHETYPES (the engines
disagree with each other by 36-40× on the archetype pathologies), two
gap-namers (schedule = the rung-4 no-threads bet; serialize = the
O-numberless whole-store verb). Kernel stays separate: pairwise
relationship-math over held values is kernel's charter, standing rules
over named reactive state are the store's — the suite needs zero
pairwise. Idea pins now have a **residue tier** below the
provisional-spelling tier: TODO + residue.md, no input.kz, for ideas
whose surface is honestly uninvented (690_019 batch+fusion, 690_020
compound columns).

**REPUDIATED (2026-07-17): the store never provides a disposal verb.** A
brief detour built a store-provided `give-back` and declared the take
obligation "explicit-discharge-required." That was wrong, and the reason is
the load-bearing insight: **on a static scalar store there is no resource.**
`take` copies the row's values out and swap-removes the slot — no `malloc`,
no `free`, ever. So an obligation that guards nothing is theater, and a
store-provided disposer is the store *presuming* how to dispose a row it
cannot know the meaning of. The corrected model:

- **A bare store's `take` carries NO obligation — frictionless** (remove +
  return values). Rung 0 (2026-07-17) retired the `give-back` unit and
  transform; a bare `take | item i |> …` needs no discharge.
- **Disposal is a PER-STORE opt-in, and the discharger is USER-authored.**
  A store declaring `[entity(<name>)]` mints `<std/store:taken!>` on a named
  synthesized row type (`Enemy`), and the USER writes the discharger — the
  *despawn handler* consuming `<!std/store:taken>` (660_027's qualified-
  phantom pattern). The compiler names the obligation until one exists; the
  store never presumes the disposal. `destroy`/`delete`/re-insert are all
  just what the user's handler chooses to do.
- **Stability from the type/state split.** The obligation *state* (`taken`)
  is stable and shared across all stores; the per-store *type* (`Enemy`)
  carries identity, disambiguated by base-type filtering (as `close(*Conn
  <!active>)` only matches `*Conn`). So the obligation vocabulary never
  multiplies with store count — the generics property in the ergonomics.

The obligation earns its keep only where a row is an entity with despawn
semantics or owned-resource cells — a per-store author's call, not a
language-wide rule. This is the disposal edge of the wider vision: the store
as a per-store-specialized, statically-allocated, compile-time-reactive data
substrate (reactions fused into the one write path, like taps).

**Rung 2 landed (2026-07-17, 690_023 green / 690_024 the MUST_FAIL wall):**
`[entity(<name>)]` on the create annotation synthesizes a user-nameable type
alias (`enemy` → `pub const Enemy = __KoruStoreRow_enemies`) and makes `take`
mint `<std/store:taken!>` on `Enemy`. The user's discharger consumes
`<std/store:!taken>` — 660_027's base-type-filtered discharge, reused whole.
The obligation *state* is shared and module-qualified; the per-store *type*
carries identity. An early rung-2 spelling kept `taken` local to dodge an
emitter coupling (`writeFieldType` fell back to the phantom's module for the
base type — right for `*Field<std/field:field>`, wrong for `Enemy`/`taken`);
that is REPUDIATED. A second spelling guessed co-location from NAME shape
(`Store` ≈ `store`), which mis-resolved any entity named like a module
(690_037); that is REPUDIATED too. `writeFieldType` now resolves the base
type's home from actual declarations — the host_type_homes registry built
over the program's final items, imported modules included — and qualifies to
the phantom's module only when that module really declares the type. The
take payload carries `module_path` for the user type; cross-module
dischargers name `input:Enemy<std/store:!taken>` (690_036).

**Rung 4 opened — plural lifecycle interceptors are BUILT (2026-07-17,
690_016 green):** `! inserted { f } |> …` and `! removed { f } |> …` on a
plural `new()` now fire from the write path itself, closing the gap the
design named at line 21 (CRUD lifecycle is the single primitive) for the
insert/take half. The mechanism is the **qbody transplant reused whole**:
each interceptor becomes an event whose inputs are its destructured row
fields plus an impl flow carrying the body, invoked from the generated
insert/take |zig via `main_module.<n>_event.handler(.{…})` — inserted after
the row append and before standing query enters (the contract runs before
subscriptions observe settled state, (h)), removed before the swap-remove
with the row's outgoing values. So a store keeps a sibling aggregate
coherent with no bus and no dispatch, on row birth/death as well as field
writes — the reactive-substrate belief now covers CRUD, not just mutation.
Field-named interceptors on plural rows, and guarded interceptors, stay
walled as later slices.

**Rung 4 closed its `updated` face (2026-07-17, 690_038/039/040/041):**
`! updated { old, new }` on a plural `new()` is the row write-contract —
the third of Ruling 5's three lifecycle primitives. The payload is the
singleton grammar of 690_003 carried over unchanged (ONE grammar, not a
plural dialect): old/new are the WRITTEN FIELD's images, and the pre-image
read is usage-synthesized per the (c) lean — the `_` discard form
synthesizes no read at all, so a store whose updated arms bind nothing
keeps a write-only write path. Two structural beliefs earned here:

- **The firing site is the apply switch, not the arm payload.** The
  singleton walls `updated` + field watches on one store because its
  updated mode FLIPS the write payload shape; the plural fires updated
  interceptors as host calls inside the write's atomic step (after the
  cell write, before the field arm dispatches), so the contract and the
  subscriptions never contend — updated + watches + guarded reactive
  rules coexist on one plural store (690_041 runs all three). The
  singleton's mixing wall is an artifact of its slice, not doctrine.
- **`updated` observes semantic writes only.** Births arrive whole (O9),
  take is a remove, and take's swap-relocation of the last row is storage
  mechanics — none of them fire it (690_040). The write path — query
  update-where and row-addressed stored — is exactly what does.

The payoff belief, proven by the arena (690_041): a maintained aggregate
riding all three faces is CORRECT BY ARITHMETIC across lifecycle seams —
overkill damage subtracts past zero at update time and the corpse's
removal restores the overshoot, so SUM(hp-of-live-rows) holds at every
settled point with no reconciliation scan. T2's cycle detector already
covered the new face (an updated arm writing its own store rejects
statically) because it scans branch names, not slices — walls built on
the general mechanism extend for free.

An interceptor payload obeys KORU100 like any binding: `! inserted { hp }`
that never reads `hp` is REJECTED — discard with `! inserted _`, or consume
the field (690_032 the wall, 690_033 the used-binding, 690_016/029 corrected
to `_`). This wall has to live in the store transform, and the reason is a
load-bearing gap worth remembering: **`flow_checker`'s KORU100 pass
deliberately skips `[transform]` invocations**, and `std/store:new` is one, so
NOTHING in the normal frontend ever checks the arms attached to it — the store
transplants the payload into a synthesized event input and the emitter then
auto-discards an unused one, so a bound-but-unused field vanished silently.
The store now scans each bound field against the body text. The general shape
(every transform that transplants a bound payload has the same latent hole;
the eventual fix is running the binding-usage check through transforms via the
DFS transform mechanism) is noted but not yet taken — surfaced by a real
program, walled store-side for now.

**Guarded reactive rules on plural stores now work (690_030).** The reactive
surface — `std/store(name) ! field h when <guard> |> …` — carried a `when`
guard on a singleton (690_026) but was walled on a plural store. The wall was
pure deferral: the guard already rides as an arm condition into the apply
switch (producer owns the `if`; cross-store guard reads rewrite to the cells),
so all that was missing was the guard-FALSE completeness. A guarded arm covers
only the true case, so — exactly as the singleton path does — the plural
warms now append an unguarded no-op sibling for that field, completing the
switch. So a plural store can hang a filtered standing rule ("fire only when
an enemy drops to ≤ 0 hp") off its reference face, guard fused into the write
path, not a runtime filter.

This slice earned its priority the honest way: writing a real program (a
wave-combat arena) made hand-bumping the scoreboard at every insert/take
site the loudest friction. That same program surfaced two further walls,
now DISENTANGLED (a bisection matters here — one was misdiagnosed at first):

- **`stored` dropped its `|>` tail (FIXED, 690_028).** The `stored` transform
  replaced its site with an EMPTY continuation list, discarding whatever was
  chained after the write — everywhere, not just in spliced bodies. The
  bisection was decisive: `print |> print` chained fine everywhere, only
  `stored |> anything` swallowed the tail. So a `stored` had to be the
  terminal step of any chain. The fix threads the original tail through
  un-marked, and it is CORRECT because the transform runner is a fixed-point
  iterator: a tail that is itself a `stored` re-lowers on the next pass. The
  "watch drops chained writes" framing was a red herring — the splice was
  innocent; the `stored` verb was eating its own continuation.
- **A value-returning impl-flow head with a void `|>` tail leaked an unused
  result (FIXED, 690_029, emitter).** Unmasked by the tail fix: before it, no
  impl flow ever had a value-producing head followed by a void chain, because
  the tail was dropped. A generated event body (the inserted/removed
  interceptor impl flow) whose head is a value-returning `__store_write`
  followed by a second write emitted `const result = …` with no discard —
  `unused local constant`. The gap lived in `emitSubflowContinuationsWithDepth`
  (emitter_helpers.zig): the parent-result discard fired only when the next
  step switched or bind-renamed, never for a plain terminal void step. The fix
  makes that discard unconditional — `_ = &<parent>;` is idempotent, and every
  path here has an in-scope parent const (top-level chains take a different
  emitter, `emitFlow`, and never reach it). So a **two-write interceptor**
  (`removed` doing `alive-1 |> kills+1`) now compiles and both writes land
  (690_029, and the arena scoreboard tracks kills). This was an emitter gap,
  not a store one — it just took a store program to surface it.

**A query branch can now TAKE its matched row (690_031) — deletion during a
sweep.** `! query { … } when … |> std/store:take(store[entity])` removes each
matching row ("sweep the dead and despawn them"), the natural bulk operation
the arena reached for. Two pieces closed it. (i) Addressing: inside a query
body a BARE `entity` (as opposed to `entity.field`) is the row cursor itself,
so it rewrites to the qbody's `__koru_qrow` input — previously it leaked as a
stray identifier into generated host code (`.row = entity`, undeclared), the
class of raw-Zig drip the koru-level wall is meant to prevent. (ii) Iteration:
`take` swap-removes, dropping the LAST row into the freed slot, so the sweep
re-checks the same index when `len` shrank instead of advancing past the row
that just moved in — the adversarial order `[5,50,8]` (taking slot 0 swaps 8
back to slot 0) is the case a naive `for i in 0..len` silently skips. A query
whose body leaves `len` unchanged advances normally, so non-mutating queries
are byte-identical. This retires the arena_showcase's GAPS #4 ("query-row
addressing is an enter-triggered standing rule, not a repeatable action"):
it IS a repeatable action now, with correct mutation-during-iteration.

**Owned columns landed and GENERALIZED — B-narrow → any owned type
(2026-07-21).** B-narrow first proved the shape for exactly
`*std/string:String<std/string:instance!>` (690_053 green / 690_054 the wall).
The SAME session then generalized it (690_055 green, `*app/lib/res:Resource<owned!>`):
a column can hold ANY `*mod:Type<state!>` — `*Player<allocated!>`, `*File<open!>`,
`*Resource<owned!>` are the same citizen. The store no longer hardcodes the
std/string tuple; it PARSES the column type (`{type, module, state}`) and
DISCOVERS the canonical discharger from the program (the one void `<!state>`-
consuming event in the type's module), then emits every site — storage cell,
insert-consume phantom, take-reissue phantom, teardown call — from those
discovered values, reusing the `buildKoruModulePath`/`<event>_event.handler`
convention. **Pure `koru_std/store.kz` work — zero compiler/`src/` change.** The
"owned-resource cells" case the disposal repudiation anticipated is now real for
arbitrary resources: the obligation THREADS the store boundary — insert's
synthesized param consumes it (push by move; a value not holding `<state!>` is a
Phantom-state-mismatch rejection), take's payload reissues it per field (pop by
move), and a synthesized teardown flow — appended LAST, so it runs after every
user flow — frees each still-live element through the canonical discharger's
handler. Ambiguous discharge (>1 void `<!state>` consumer, e.g. commit|rollback)
stays the 690_035 drain wall — the caller-driven drain is the later rung. Three
structural beliefs earned:

- **The reissue rides the branch-payload FIELD seeding, not the identity
  payload.** An owned store's `| item` payload is a STRUCT of row fields
  (not `__type_ref`), because both checkers already seed per-field
  obligations on struct branch payloads (`binding.field` keys) and — unlike
  bare-return record fields, which are `not_auto_dischargeable` by design
  (330_096's wall) — branch-payload field obligations auto-discharge. So
  `i.name` auto-frees at scope exit with zero new checker code.
- **Generation-time phantoms must land in the DOT-canonical island.** The
  auto-discharge finder compares canonicalized `module:state` strings
  verbatim; std/string's bare states canonicalize through the module's
  logical dot-name. A slash-spelled generated phantom
  (`std/string:instance!`) misses `free`'s `!instance` and KORU030s in the
  AUTO-DISCHARGE FINDER — `findDisposalEventsForState` compares `module:state`
  strings verbatim (no separator tolerance) — probed in isolation before
  building. This is FINDER-PATH-specific: the EXPLICIT-consume path
  (`validateArgument` → `canonicalizePhantomState` → `lookupModule`) IS
  slash<->dot tolerant, so a user-decl slash-qualified issue AND consume unify
  fine (330_087 green; isolated slash-issue probe compiles). So 330_087 is NOT
  the unbuilt-migration pin — it tests explicit cross-module qualified consume,
  which works; the dot-canonical island requirement stands only because the
  finder path is verbatim. The entity phantoms live in a parallel slash island
  where both sides are source-spelled — the two islands must not be mixed
  per obligation.
- **One obligation surface per store, and no un-commissioned surface half
  works.** The canonical-discharge rule (exactly ONE void `<!instance>`
  consumer on `*String` — the 690_035 ambiguity wall applied at the column
  boundary) is enforced at create; `[entity]`/`[tree]`/char mixes,
  watch/query/interceptors/`stored`, and insert's `| full` (whose early
  return would consume the caller's obligation without keeping the value —
  a silent ownership leak) are all loud later-rung walls, and an owned
  store generates no write surface at all rather than one that moves owned
  pointers without their obligations.

**Owned-column WRITE + watch landed (2026-07-22, 690_062 write / 690_063
watch).** The "an owned store generates no write surface at all" belief above
is now SCOPED, not retired: a **canonical-discharger** owned store gets the
full write+watch surface; only a **drain** store (ambiguous discharger) keeps
none. `stored{}` over an owned column is **discharge-old + consume-new** —
Rust's `vec[i]=x` made koru-explicit: unit-4's apply/write pair generates for
owned stores (gated `!drain_required`, NOT `!has_owned` — the boundary the
build sharpened), the value slot carries the consume-phantom (insert's move-in
reused), and the apply arm reads the OLD pointer, fires the discovered
canonical discharger, then moves the new one in. The eviction is *why* a drain
store is walled: with >1 `<!state>` consumer there is no single discharger to
free the evicted value, so a drain store correctly gets no write surface and
`stored`/`watch` name the drain boundary. `watch` over an owned column fires on
that write — the apply branch payload carries the **bare-borrow** phantom (the
690_060 query projection) and the arm reads the field FRESH from the cell
(690_061's rule), so the subscription borrow-reads the just-written value and
consumes nothing (the store keeps the live `<state!>` it frees at teardown).
The `updated` interceptor over owned stays an honest later rung (it carries TWO
owned images — old and new — of the written field, distinct from removed's
single outgoing borrow). REMOVED over owned IS built (2026-07-22, 690_065): the
`removed` interceptor fires in the take path before the swap-remove,
bare-borrow-reading the outgoing row via the SAME `LC.emit` projection as
`inserted`/`query` — and the finding is that it needed NO new codegen, only an
unwall. `LC.emit` already built the bare-borrow payload for any owned arm field,
and the take proc already fired `removed` with the outgoing copies; the
create-time wall rejected `removed`/`updated` together purely out of caution.
Splitting it (admit `removed`, keep `updated`) is the whole change — react-on-
delete for a reactive todo. Still pure `koru_std/store.kz`, generalized via
`field_owned_info`. This closes Path B's
read→react→write arc: an owned column is now a first-class writable, reactive
citizen. The consume rides the user-facing `__store_write_*` event; the
internal apply proc receives the already-owned plain pointer (the two-hop
phantom placement the build resolved).

**MIXED-field write DE-BUNDLED (2026-07-22, 690_064) — the `captured` model.**
The WRITE rung above bundled all columns into one `__store_write_<s>(row,
field, value_0..n)` event (690_049), unwritten slots riding as typed zeros. A
scalar's zero is cheap; an OWNED slot has NO typed zero (its value is a consumed
obligation), so writing a NON-owned field of a `{label: owned, done: i64}`
store was walled — a `done`-only write couldn't fill `label`'s slot. The fix is
`control.kz`'s `captured` model made concrete: for an owned-containing store the
write is DE-BUNDLED into one TARGETED per-field event `__store_fwrite_<s>_<i>
(row, value)` threading ONLY that field's value. A scalar write never references
an owned sibling's slot or its obligation; the owned field's own write keeps the
consume-phantom on its single `value` (discharge-old in its apply arm, watch off
the fresh cell read). The bundling was signature-only — the apply switch's arm
for field `i` already wrote only cell `i` — so this is a mechanical split, not
new semantics: scalar-only stores keep the untouched bundled 690_049 path, and
the bundled surface stays as the DISCOVERY surface (field order, column types,
watch-splice marker) for owned stores. Distinct `fwrite`/`fapply` prefixes are
load-bearing: store-name discovery strips `__store_apply_`/`__store_write_`, so
a per-field name sharing them would parse as a bogus store. This unblocks a real
reactive todo store — toggle `done` AND rename `label` in one `{owned, scalar}`
table.

The full residue (rulings, stamped theses, gauntlet verdicts, open
queue) lives in `tests/regression/600_STDLIB/690_STORE/DESIGN.md`, which
deletes as pins absorb it. ECT/BLOOM (entity-component-taps) is
superseded by this design; its rings pattern is salvaged as the async
escape from the cascade.

## The ECS story's blocker is the CAPTURE SET, not module resolution (2026-08-03)

Measured rather than assumed, because the standing belief was that module
resolution held the Bevy comparison back. It does not, and has not for a while:

- A store declared in one module and swept-and-written by a system in ANOTHER
  module works today. Stores are linkable from anywhere by bare name, ruled and
  green (690_088). A three-file `world` / `movement` / `main` program with the
  integrate system in its own module compiles and runs correctly.
- The comptime module-mirror wall stands at 41/42, and its ONE red (115_020) is
  not a module defect: it mirrors 690_069, which is deliberately red awaiting
  the row-ordinal spelling ruling. A mirror of a red pin says nothing.

What actually blocks a real workload is one gap, and it is orthogonal to
modules: **a sweep body cannot reach the enclosing tor's INPUT.** `pos += vel *
dt` — the single most common thing an ECS system does — fails with a raw Zig
`use of undeclared identifier 'dt'`. The entry-file twin fails identically, so
this is not a boundary effect (690_243 pins it, red).

The asymmetry is the whole argument. 690_073 is green and captures a mid-chain
BIND into that exact body position. An enclosing tor's input is declared in the
signature — at least as enumerable as a mid-chain bind — and does not arrive.
The machinery is already there and already threaded: `Cap.collectEventInputs`
is called only when the holding flow is a synthesized `__store_sweepbody_`, so
a sweep nested in another sweep sees inputs and a sweep in a user tor does not.
A universal property installed at one of several exits, again.

**CLOSED the same day, and the "ruling" framing was wrong.** I wrote here that
this was a question Lars owned — that T1 lists the legal free names of a
transplanted body, an event input is not among them, so the refusal was T1
working as written. **Repudiated.** T1 governs a WATCH body: spliced into the
store's write path and executed wherever a write happens, which is why it
cannot close over its declaring scope. A sweep body runs AT the sweep site, in
the caller's own frame; its lift into a handler fn is codegen, not relocation
to a foreign execution context. Conflating the two is what made a mechanical
omission look like a design boundary.

The corpus already knew. `690_234_impl_param_not_captured_into_sweep_arm`
recorded it as "a documented gap, red on purpose", named the same
branch-binding contrast, and carried its own flip instruction — "when param
capture lands, this flips to MUST_RUN with expected '7 5'". I did not find it
because I grepped for the PROSE of the gap and it was in the test's NAME.
Searching for a description finds authors who describe; the corpus indexes by
what a thing IS.

The fix was one gate: the collector called `Cap.collectEventInputs` only when
the host flow was a synthesized `__store_sweepbody_`, so a user tor never took
that branch. Both hops of threading already worked — a sweep arm inside a tor
body captures a mid-chain bind today. The measurement that settled it: the same
`dt`, the same body, reached the arm as `tick(): dt |> query …` and not as a
declared parameter. One origin, not one scope. 690_234 flipped green, 690_243
pins the ECS spelling, and the cost 690_234 named — a helper tor that writes a
store having to be inlined at its call sites — is paid off.

Also standing, and worth stating because it is easy to misread as progress:
the 003_ecs_reactive harness has anchors for Bevy, Flecs, Unity DOTS and a Zig
baseline, and NO Koru entry. The comparison is unmeasured, not unfavourable.

## The query's destructure block is a REQUEST, and its entries take annotations (ruled 2026-08-03)

Lars ruled this after the row-ordinal pin (690_069) sat unspellable for a week.
The block is not a projection of columns; it is a list of things the VISIT can
synthesize, each carrying a prefix annotation naming what is wanted:

    ! query { [row]e, [ordinal]n } |> … n … e.v …

Four parts to the ruling. The block synthesizes **only what is asked for** (an
unrequested ordinal materializes no cursor — the same demand-driven rule TT3
already applies to aggregates). Entries use the language's normal **prefix**
annotation form; `r[mutable]` is postfix only because it hangs off a binding.
It is **local to query/store** and explicitly does NOT generalize — `for` has
the identical missing-counter hole and does not get this, because the store's
query is the thing that already drives codegen. And every annotation is
**honored or refused**, never silently ignored, under the same law as declared
reductions.

### Why the braces are legal again

Three separate things had collapsed under one word, "retired", and only two of
them ever had an argument:

- `entity.v` — an unscoped magic token; killed because the rewrite matched a
  literal word across a subtree with no scope (690_087). Never applied to
  bindings, which are distinct tokens per nesting level.
- a COLUMN LIST — killed because it "said the same thing twice and let the two
  halves disagree"; the column set is DERIVED from `<row>.<field>` references.
- the BRACES — no argument, ever. The wall is written `sc.destructure.len > 0`:
  a syntactic ban on brackets standing in for an argument about column lists.

An annotated request is untouched by all three. Nothing in it is a column, so
nothing is stated twice and columns stay derived; every entry is a binding, so
nesting stays unambiguous. **The lesson generalises past this feature: when a
wall is implemented as a shape test but justified by a semantic argument, the
two have different extents, and the gap is where good ideas get refused.** Same
shape as the capture gate two sections above, found the same afternoon.

### Why this surface and not another

Layout is already the closure of the queries — projections become SoA columns,
predicates become maintained views. The query is therefore the planner's
existing input, and annotating it needs no new plumbing and is comptime-visible
exactly where the store transform runs. It also lets things that are currently
INFERRED be DECLARED: the dense cursor behind the row-tax result (four
`fadd.2d` against twenty scalar instructions) is a codegen decision the author
cannot presently express.

It also gives the handle/position distinction a spelling. A cell names a row by
HANDLE, never by position (ruled); `[id]` and `[ordinal]` make that visible in
the source instead of implied by a comment, which is what the old bare `row`
got wrong.

RULED 2026-08-03: the block may NOT name columns (see the refusal derivation
below). `690_069`'s open note is closed with it.

### The third member arrived, and it arrived on evidence (2026-08-03)

`[id]` is built (690_246). It was held back deliberately — the position was
"the benchmark is the instrument that should answer this, and ruling early
risks a vocabulary nobody asked for." A borrowed ECS workload then asked for
it, and the demand was measured rather than imagined: an intrusive bucket chain
needs a visited row to write ITSELF as the new head, every other piece of that
structure already worked, and `[id]` was the single remaining blocker. That is
the shape of evidence this vocabulary should require of every future member.

**RULED 2026-08-03 (Lars).** Two clauses — and they are not two tests of the
same kind. The first draft had only clause 1, and an adversarial review holed
it three ways in one pass; the corrections are folded in below rather than
recorded as an afterthought, because the corrected gate is a different object
from the one first written.

> **1. ADMISSION (NECESSARY) — a request names something the SITE knows and
> the ROW does not.**
>
> **2. RETENTION (SUFFICIENT) — a request whose value may OUTLIVE the visit
> must be generation-checked. One that cannot be generation-checked is
> visit-scoped and may not be stored.**

**Clause 1 is NECESSARY, clause 2 is what makes the pair SUFFICIENT, and
neither is the gate on its own.** That sentence is part of the ruling because
the review's real finding was not any single hole — it was that clause 1 READS
like a complete gate, and the draft's own author read it that way. `[slot]`
below is the proof: it satisfies clause 1 as literally as `[id]` does and is
the worst value this surface could hand out.

Clause 2 is about ADDRESSES specifically. "Generation-checked" is meaningful
only for a value that names a row; a request that is a plain FACT rather than
an address (a count, an extent) has no generation to check, so clause 2 refuses
to let it be stored. That is the right answer reached through slightly
address-shaped language, and it is noted rather than fixed: no member of that
kind has been asked for, and minting a third clause for a hypothetical is
exactly the vocabulary inflation this gate exists to prevent.

- `[row]` — which row this is. The site knows; a row cannot name itself.
- `[id]` — the row's identity as a value. Admissible by 1, and **retainable by
  2**: a handle carries brand and generation, so a stale one traps loudly.
- `[ordinal]` — where in the traversal. Admissible by 1, **visit-scoped by 2**:
  a take swap-removes the last row into the freed slot, so a stored ordinal
  silently names a different row one removal later.
- `[slot]` — the handle's slot with the generation word dropped. **This is why
  clause 2 exists.** It passes clause 1 as literally as `[id]` does — the store
  reads exactly this value at the cursor and no column holds it — and it is the
  single worst value this surface could hand out. A stale slot passes the brand
  check and the bounds check; the generation compare is the only thing that
  would catch a recycled slot, and `[slot]` is that value with the generation
  removed. It reopens by construction the door brand-0 reservation was closed
  to shut. A gate that admits it is a taxonomy, not an invariant.
- a **column** — **REFUSED, ruled 2026-08-03**, and it rests on TWO arguments,
  not one. Clause 1 derives it: a column belongs to the ROW, so it fails the
  test. But that derivation does not supply the HARM — nothing in "the site
  knows and the row does not" says restating row knowledge is harmful rather
  than merely redundant, and claiming the gate had absorbed the older argument
  was the second thing the review caught. The harm comes from DUPLICATION,
  which stands beside the gate and is what killed the projection block: the
  block said the same thing twice and let the two halves disagree. Both
  arguments are load-bearing; the refusal needs both.

Second clause of the ORIGINAL kind, inherited rather than invented:
**synthesized only when named.** An unrequested member threads nothing and
costs nothing, so the argument against a member is only ever "no workload wants
it", never "it slows the others down".

WITHDRAWN: the first draft refused "a store-wide fact (row count, capacity)" as
not-visit-knowledge, and twelve lines later admitted a request for the sweep's
own length. Those are the same value — the sweep's extent IS the store's live
row count, read once at loop entry — so the bullet was refusing and admitting
one thing under two names. `[last]` smuggles it a second way, being definable
as `ordinal == len - 1`. There may be a principled line between "how many rows
exist" and "how far this walk goes", but it would have to be about intent
rather than extent, and no workload has asked for either.

**RULED 2026-08-03: `[id]` is admissible on a standing `rule` and on
`preorder`, and the refusal there was a phrasing bug, not a boundary.** The
request block was parsed only on the sweep arm, so a `rule` destructure hit a
diagnostic naming it "the retired projection block" — a wrong error on a legal
construct. Clause 1 says SITE, not VISIT, precisely so this is answerable: a
rule has a ROW and no TRAVERSAL, so `[id]` is exactly as meaningful there as on
a sweep (a handle does not depend on traversal), while `[ordinal]` is genuinely
meaningless there and must be refused BY NAME with its own reason. A gate
phrased around "the VISIT" would have collapsed *meaningless here* and
*meaningful but unimplemented* into one answer; that is the whole reason the
word is SITE. The motivating workload is the one that earned `[id]`
originally — a reactive chain update is the same shape as the sweep that
needed it.

**BUILT the same day, and the gate paid for itself in the diagnostics.**
`690_247` is the rule half and it is a RETENTION proof, not just an admission
one: the rule marks a row's handle into a sibling store, a `take` then
swap-removes a *different* row so the marked row relocates, and the write that
follows the stored handle still lands on it. A position would have addressed a
dense slot past `len` and inside capacity — the exact silent corruption
`690_092` measured before O10.iii shipped. `695_005` is the `preorder` half.
`690_248` pins the `[ordinal]` refusal, and its diagnostic says "this is not
unimplemented; it is meaningless here" in as many words — the sentence exists
because the gate distinguishes those two and a reader could not otherwise tell
which they had hit.

Two things fell out of building it that the ruling did not anticipate:

- **The row and its handle need two names.** `! row { [row]e, [id]e }` would
  mint two event inputs spelled the same and emit a duplicate struct field
  instead of a diagnostic — the collision the store review found and left
  unfixed. It is refused here, where both names are known, which closes the
  rule-arm instance but NOT the general one (a request name colliding with a
  *lexical capture* still emits the duplicate field).
- **The handle is bound before the guard**, so a guard may name it. Nothing
  demanded that; it costs nothing, and refusing it would have been a second
  boundary to explain.

Also confirmed while building: `rule` is ENTER-ON-INSERT, not write-triggered.
The write-triggered surface is the reference face (`std/store(s) ! <field> h
when …`, 690_030). Two reactive surfaces with different trigger semantics and
adjacent spellings; the distinction is nowhere in the prose and cost a probe to
rediscover.

## The sum-side vocabulary: view / set / kind / union (evolved 2026-09-06)

The store surface's sum side is a LADDER with one law — **exclusivity at
storage, overlap at projection**:

    protos → stores (kind | new) → claims (set over kinds, union over new) → views (over anything with storage)

- `new` names a proto and is never coupled to `kind` (Lars-ruled): a program
  that never uses sets declares no kinds. Members of view and union.
- `kind` is a set member: shape + kind ordinal, no storage, no capacity slot.
  One binding per name — `kind(Player)` + `new(Player)` is refused (the
  insert target must never be ambiguous, and no hidden priority rule
  decides it).
- `set` is a pool over kinds: pool-level capacity, kind-agnostic entries, the
  physical fold (contiguous shared leaves, per-row tag). Writes route through
  the kind — the kind name IS the kind; the set has no polymorphic insert.
  Aspirational: 690_296 pins the target. The kinded lone store (690_274/275)
  already emits the shape the set inherits. BLOCKED on a missing surface
  (Lars, 2026-09-06): the kind layer is an ABSTRACT/VIRTUAL shape —
  `kind(Player)` declares shape + identity with no storage, and the set's
  dispatch (inserts route through the kind; queries dispatch over kind
  identities) needs abstract/virtual machinery, not just a fold. No such
  surface exists in the language today; recorded in 690_296's header.
- `union` is an exclusive pool over new stores: one active kind at a time,
  C-union semantics, memory = max member, kind = one register, previous
  kind's data gone on switch. Switch semantics (empty-only vs reinterpret vs
  migrate) is OPEN and brushes the O13 ruling. **POSTPONED (Lars-ruled
  2026-09-06)**: "an exercise in more than just if over a collection" — its
  runtime content is comptime layout (extent = max member) plus program state
  (which kind is active), its reads are views already, and an exclusive sweep
  is just the active member's own loops, so there is nothing runtime in it to
  measure. No implementation work scheduled; revisit only for a workload that
  needs static extent reuse (unikernel footprint).
- `view` is a projection over anything with storage: no storage of its own,
  kind never materializes (a per-member constant), overlap free, read-mostly.
  The landing `set` behavior IS this construct — hence the rename (690_287
  and the refusal cluster re-spelled).

Kind materialization is the axis that orders the space: view never, set per
row, union one register. The coexistence question (do kinds coexist in
time?) separates set (yes) from union (no). The set's coexistence tax — the
per-row tag — is measured against the view in the 006 benchmark: ≈3× on
read-mostly sweeps, data for the set's flat-vs-segmented open question when
the set lands.

Arity (ruled): one claim per store; claims take layer-1 declarations only
(no set-in-set, no union-in-set); set/union/view each need ≥ 2 members. The
design test: every refused composition has a one-word alternative
(store-in-two-sets → view; set-in-set → view over sets; singleton → the
store or the query). A refusal with no alternative is the only design hole.

**`! first` + `| none` (2026-10-13): the sweep arm vocabulary gained
early-exit find.** `std/store:query(s)` accepts `! first <row> when <cond>`
as `! query`'s alternative — same binding, same guard, same derived
projection — stopping the sweep after the first matching visit, with
`| none` (the established absent-case spelling: 320_090, 220_012) firing
when no row matched. The pair is the find-or-join a plain sweep cannot
express: the asteroids-net input path had been hand-rolling it as a
full-store scan writing a sentinel into a scratch grid, with a `pid == 0`
check downstream to mean "not found."

The arm exists BECAUSE position is never identity — it is the consequence
of that ruling made operational. A "find one row" site cannot cache the
answer positionally (`take` swap-removes the last row into the freed
slot), and the interceptor route to an index fails the same way: the
lifecycle vocabulary (`inserted`/`removed`/`updated`/`cleared`) fires for
the taken row but not for the row MOVED into its slot, so a key→slot map
maintained by contract would silently point at the wrong row after every
non-last take. Two holes close it if the map road is ever taken: slot
visibility in arm payloads, and a `moved` arm — but a store-owned index
declaration would absorb swap-remove inside `take`'s own emit instead,
which is the structural answer if scans ever actually bind.

Measured honest: at 128 sessions the `first` conversion was
performance-neutral (≈41 Hz both ways) — the input path's cost is
per-packet fixed overhead (~40µs/pkt: recv, decode, dispatch), not row
visits. `first` earns its place as the semantic spelling, not as the
perf fix; an `indexed` column remains the tool for the day the scan is
the measured cost.

Open gap found along the way, unfixed: a `! each`-style ancestor arm
binding is invisible to a nested sweep's capture threading — `lookupBranch`
resolves arm payload types only against `event_decl`s, and `for` is a tor
whose `! each *` declares none. Tor inputs and mid-pipe binds thread fine;
arm bindings of transform-declared events do not.

Measured 2026-09-19 (690_127, a 16-output 4x4 inverse over flattened
columns): the O10.iv dense cursor reached the sweep body as `i64` — the
write family's row convention — and every `.live` column read cast it
back to `usize` at the operand: 1504 casts on one emitted line, one per
column mention. Zig's comptime quota was the instrument that noticed, not
a profiler. The dense row is now `usize` end to end — sweep cursor, rule cursor,
every write-family `row` input — and the only casts left are at the
handle boundary (`__koru_resolve`, `__koru_handle_of`, `[ordinal]`).

Compound column substrate — measured (2026-09-20, `mat_shape_ab` probe):
a vec/mat field flattens to scalar leaves, full stop. The tier-2/3 open
question in 690_020 ("one compound cell vs scalar leaves") was decided by
the workload that raised it: on a mat4 inverse over 10k rows, 32 flat
columns run ~80us/pass where a `[16]f64` compound cell runs ~153us — LLVM
vectorizes scalar columns across ROWS, and a row-local array can never
form that vector. The compound declaration is sugar over the fast shape
(`[4][4]f64` -> `ProtoExpander` leaves, ranged writes unrolling into
today's envelope), not a new cell type. The real cost of flattening is
write-mask width — a 4x4 pair already spends 32 of 64 mask bits — not
speed. Chunked envelopes or a wider mask are the follow-on when tables
get wide.

Handle machinery is the closure of the observations (2026-09-20, lean
store): a store nothing can observe by identity emits no handle tables at
all — no hslot freelist, no generation table, no resolve. The gate is a
whole-program scan (`Gate` in store.gate.kz): `[tree]`, `! step`, declared
indexes, `[id]` requests, rules that may remove, indexed references, bound
`| row`, any `take`, or anything unparseable keeps the full machinery;
otherwise insert is `col[len] = v; len++`. Measured on 003_ecs_reactive:
add_remove 0.53ms -> ~0.28ms, insert 3.3 -> ~2.5ns/row. The same TakeScan
predicate that picks a rule's loop form now gates the store's storage —
removal tolerance and handle elision are one observation question asked at
two boundaries. What the program cannot see, the emitter does not build.

Bulk append is the same observation question at the loop boundary
(2026-09-20, `~part bulk`): a counted `for` whose `! each` body is a
single insert into an observation-free store lowers to one hoisted
capacity check, column writes at `base + j`, and one `len += n`. The
paragraph above ended with "the rest of the churn gap vs plain Zig is
model distance, not machinery" — measured wrong within hours. The
per-row `len += 1` is a loop-carried store no optimizer can reassociate
past the per-row capacity panic, and it was the fill's real cost — not
the event-call marshal, which LLVM already ate (marking the impl
`inline` moved nothing). Hand-editing the emitted loop proved it before
the transform existed: 294us -> 89us; the shipped lowering lands ~63-77us
for 100k rows on the same port's `mark-init`. A `| done` arm survives
via the same `__koru_continue` marker the template renders. Neither end
of the pattern could see the other — insert's transform is site-local,
`for`'s body is an opaque splice marker — so the recognizer lives in
`new`'s whole-program walk, the one place both sides are visible.

Handles did not actually disqualify the tier (2026-09-21, 690_338) —
the earlier gate was over-strict on two counts, and relaxing both kept
the semantics exact. First, handle minting is a pure function of two
counters: a batch mints the identical slot sequence by popping the
freelist LIFO (`free[frem-1-j]`) then bump-allocating (`next+k`), so
refilled handles, freelist order, and generation counters are
indistinguishable from per-row inserts — the write-set floor for the
full nine-stream insert is ~1.6ns/row in plain Zig while the per-row
path paid ~7.4ns. Second, the one thing a batch cannot reproduce is a
reactive enter — but enters are positional, not existential: the
per-row emitter already gates them with `__site_line > qs.line`, so a
counted-for whose insert sits above every non-preorder qsite's declared
line fires nothing, per-row or batched. The gate therefore keeps only
what is per-row semantic: lifecycle arms, watches, facets, kinds,
owned/fixed-char columns, trees, `! step`, index columns (the
needs_handles blanket had been silently covering trees, steps, and
indexes — dropping it required naming them). Measured on
003_ecs_reactive: spawn 738->~500us, despawn 917->~773us, and every
scenario that builds its world inside the timed region moved with it
(dense crossed under the zig_striped anchor).

The gate's scan domain is the set of modules that can textually NAME the
store — not the whole program (2026-09-21, 690_335). flatItems returns
every loaded module's items including koru_std's own bodies, and the
name-substring predicates cannot tell a program store from a stdlib
local: `.items[` (the ArrayList idiom all over store.new.kz), `names[i]`
at store.kz:406, `data[wi]` in field.kz, `fields[i]` in interpreter.run
all read as `store[` / bare-bind to the scan, so stores named `items`,
`names`, `data`, `fields` kept full handle machinery purely by
identifier. The conservative direction had a cost the contract never
priced: a false positive is not safe, it is a silent deopt. Two fixes,
both measured against the same probe: the scan now walks only
non-koru_std module bodies plus the store's own home
(`H.visibleStoreItems` — koru_std source predates the program and cannot
spell its stores), and every `name`-at-boundary matcher gained the
`.name` member-access exclusion `storeRefsText` already carried —
`x.items[i]` is a member index on `x`, never the store. The same
exclusion went into the rewriters (`storeIndexedRefs`,
insert/stored `storeRefs`, qrewrite `bind.`): a `.items[` match there
would have been a miscompile, not just a pessimization.

`std/indexes:store` is a key→ORDERED-HANDLE-BUCKET map, and one
declaration now serves both consumers (2026-09-22, 690_341/342):
`! first` answers the bucket's lowest dense LIVE member (the sweep's
first-match parity, 690_327) and `! query <row> when <row>.<col> == <k>`
walks the bucket instead of sweeping — membership IS the guard. The
widening is what made take free: a taken row's handle stays in its
bucket as a dead member that `__koru_row_of` resolves to none, so the
index emits nothing at take and swap-remove needs no fixup (a handle is
unchanged when its row moves dense slots). `stored` writes to the
indexed column move membership eagerly; `clear` drops every bucket with
the map; and the counted-`for ! each` bulk lowering keeps the index too —
the batch emits the bucket join inside its fill loop (the next paragraph
has the measurement that forced this).

The routed walk comes in two shapes, picked by a scan the body already
had a cousin of (`armReachesInvocation`, the `TakeScan` machinery): a
body that cannot touch the bucket — no insert/clear on this store, no
write to the indexed column — gets a `for` over the captured slice, one
map probe for the whole query; a body that can gets a `while` whose
post-body survival check re-reads the bucket and re-examines the slot a
moved member vacated (690_031's re-check contract at bucket
granularity). Visit ORDER under the route is bucket order — join order
— identical to the sweep's until a take reshuffles dense slots; the
divergence is a ruling, not an accident. Measured on 003_ecs_reactive
`sparse` (ReleaseFast, 100k×100f): the sweep paid ~4.7ms visiting 100k
rows for a 10k-member set; the bucket walk pays ~4.4ms for the same
output — the visit-set gap closed, and what remains is per-member cost
(handle resolve + event chain) against the baseline's bare index read,
~2ns vs ~1.1ns a visit. That residual is the next lever, and it is
dispatch overhead, not membership.

The bulk decline did not survive contact with the phase-split measurement
(2026-09-22, 690_342 rewritten): once `sparse` decomposed into init (~1.3ms
of 4.1) versus walk, the per-row insert path was the init cost — and
`world-init` is a counted `for ! each`, the exact shape the bulk lowering
exists for. The gate's reason for refusing was real (the batch writes
columns raw, invisible to the bucket map) but the remedy was maintenance,
not refusal: the bulk loop now emits the bucket join per row, with a
loop-local bucket memo that re-probes only when the key changes — "same
as the previous row's cell" is the run detector, no typed memo state
needed. Indexed stores get the fast fill AND the index. Fresh ReleaseFast
numbers on the same benchmark: spawn 1.32→0.95ms, sparse ~4.05→~3.83ms.
What remains against zig_striped (sparse ~2.15ms): ~0.6ms of init the
baseline never pays (bucket appends + handle mint) and ~1ns/member of
generational handle resolve in the walk — the price of take-safety the
baseline's bare usize index does not carry.

A query guard is not body text (2026-09-22): walking the arm's own `when`
into the body's column-usage marks projected the guard's column into
every event payload — a dead read per member on routed queries. The fix
was not to skip the walk but to redirect it: the guard rewrites against a
scratch column set and its text STAYS on the clone, because collectRefs
reads that text for ambient-bind capture and the bound-but-unused check —
nulling it (the first attempt) broke 690_093's interceptor payload.
Routing then restores the body-only marks so the guard's columns are
emitted once, in the loop, for `guard_z` — and never in the payload.

The drain gate had a stale doubt of its own (2026-09-22, 690_336
extended): the take-only-rule lowering declined indexed stores on the
theory that "an index column reseats entries per take" — but take
reseats nothing. Dead handles stay in their buckets and resolve to no
live row, so a drain's bookkeeping-only teardown leaves the index in
exactly the state sequential take would. The decline was survival of an
earlier mental model; removing it puts `despawn`'s drain back on the
traversal (ReleaseFast: ~1.79→~1.31ms), and the pin now proves routed
lookups over a drained index skip dead members while the standing rule
still eats later inserts.

The handle mapping is lazy (2026-09-23, `__koru_ident` in
`store.hstruct.kz`): a store that has never removed a row satisfies
slot == dense index for every live handle, so `hslot_row`/`row_hslot`
carry undefined bytes no reader may consult. Mint and the bulk fill
skip both table writes, `row_of`/`handle_of` skip the table load, and
the first take pays one `t[i] = i` materialise pass before flipping the
flag. Drain cannot re-arm it — the freelist it fills is exactly what
makes slots ≠ rows — but under identity the freelist sequence is known
arithmetically (`0, n-1 .. 1`), so drain's teardown is three streaming
passes with no tombstone writes: dead table bytes are unreachable
behind the bumped generations. `clear` re-arms because its canonical
reset empties every handle structure. Measured on 003_ecs_reactive
(ReleaseFast, 100k×100f): sparse ~4.05→~3.5ms — the resolve fast path
sheds the per-member table load; the drain is ~185µs vs ~350. What the
flag did NOT move is init: the skipped table writes were never the
cold cost — the ~0.5ms cold/warm delta is column pages and bucket
heap, which no flag removes. An earlier per-row `if (ident)` select in
the drain loop measured ~110µs worse than splitting the variants —
hoist the branch, never fold it into the row computation.

The bulk bucket join is memoized twice over (2026-09-24): the probed
bucket rides `__koru_im` while the key repeats, and a one-entry cache
of the just-left bucket (`_mk`/`_mp`) makes alternating keys probe-free
— the boundary walks of a two-key batch never re-enter the map. A
fresh-key `getOrPut` can rehash, so the cache is invalidated the moment
`!found_existing` (`_fk`); a cached `value_ptr` across a rehash is a
dangling pointer, and "cache only when nothing moved" is the whole
invariant. The member append is spelled inline — a capacity check plus
a direct `items.ptr[len]` store — because the method's call shape
measured ~65µs slower at 100k rows. Measured (003_ecs_reactive,
ReleaseFast): world-init's index join ~480→~350µs; spawn ~1.09→0.73ms,
despawn ~1.29→0.95ms, sparse ~3.58→~3.17ms, sinks identical.

`__koru_gen0` records that no generation bump has ever run (2026-09-24):
birth-true, cleared at every gen-write site — take's tail, the sweep
verb's bump, drain, and clear's `0..hslot_next` pass, where
`gen0 = gen0 and next == 0` keeps it across a clear of an already-empty
store. No bump ever ran means no removal ever ran, so slot == row for
every minted slot and every outstanding handle carries gen 0 — the
invariant stands on removal-freedom alone, independent of `ident`
(a stray `materialise` on an empty store can clear `ident` with `gen0`
still sound). Under it `row_of`/`resolve` shed the `hslot_gen` load and
`handle_of` sheds the compose load: resolve is brand check + range
check + shift. Measured (003_ecs_reactive, ReleaseFast): sparse
~3.17→2.78ms, spawn ~729→700µs, sinks identical. A counting/presize
bucket build measured WORSE than the fused memo'd join (~280 vs ~205µs
micro) — the realloc copies amortise below the cost of a second pass;
the join stays fused.

The write side has its own floor (2026-09-24): a `stored { acc.f: acc.f + e }`
inside a hot inner loop is a load-modify-store chain through a heap column,
and LLVM does not promote the cell across iterations — the store's
per-write visibility is the semantics, and a serial ~1ns RMW per write is
its price. In `fanout`'s observer loop that was ~3 ms of a 5.5 ms gap over
the baseline's register accumulator. The honest shape is `capture`: the
fold accumulates in a comptime cell and lands one store write per event —
identical sink, one observable write, and the baseline's loop shape. The
fold is not a workaround for a missing optimization; per-hit write-through
IS the correct cost when a cell is written per hit. `captured` inside a
`std/store:query` arm does not lower (the query body is transplanted out
of the transform's subtree) — per-row folds across a query still pay the
write-through, which is where the next store-side lever lives.
