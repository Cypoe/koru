# Law participation — the surgical plan

*Status: plan distilled from the gdp-wired transcript
(`2026-10-27-verification-lane-and-discipline`) and Lars's working paper
(`2026-10-25-proof-participation-for-collaboration.md`), sharpened against
the `ccomp` tree as of bd7fe0079. Every "exists" below names a file or a
verdict that ran this week; "proposed" does not exist.*

*Update (same tree, after 071dc4164): the §1 linear-atom rung LANDED —
`& a + b <= c` (plus implicit-self `& <= balance + margin`, `==`, `>=`,
coefficients) parses into `LinRow`s that meet by union; `linCheck` runs
integer-exact Fourier–Motzkin over the row set *plus* the per-field
bounds/eq/clamp/alts-hull (a bound is a one-term row) and refuses the
empty meet naming every contributing atom. Fence: >3 vars, >64 rows in,
>256 derived rows → `outside`, not a verdict. Rows land on `facet_decl`
as typed `FacetLinRow`s (serializer + cloner carry them) and report as
declared data until a row-predicate consumer exists. 671_036–039 pin
it; the 671 range is 39/39 green. Still proposed below: the prover
reader itself.*

*Update (same tree, uncommitted): the §4 claim surface LANDED as
declaration-and-validation infrastructure — the `std/spec:claim` tor
(`atom:`/`on:` args + Source body), the atom registry (`terminates`,
required `"rank"`, semantics documented in std/spec), and
`pass-claims-check` in the analysis chain after `pass-witness-check`.
Lifecycle measured this session: a `[comptime|norun]` site's flow is
stripped in elaborate Phase 3 — harvesting the way realize does is too
late, so `claim` carries a `[comptime]` proc that registers the site
(atom/on/rank + InvocationMeta location) into `spec.claim_registry`
when comptime_main executes it, and the analysis pass reads the
registry. KORU213 refusals: unregistered atom, `on:` naming zero or
two+ tors (bare `on` matches only the program's own decls — never a
stdlib tor sharing the last segment), missing required fields, `rank`
not a linear form, rank naming a non-input-field. Census:
`[claim] file:line atom on subject: declared`. Two structural
consequences: `LinPart`/`parseLinExpr` moved from `std/refine` to
`std/spec` (spec is core-emittable; refine is opt-in and the pass runs
in every backend), and `~import std/spec` joined compiler.kz — which
meant `spec.revision` had to shed its `|zig`-only proc for a portable
bare-Koru impl (`-> "std/spec:0"`) or every C compile refused
KORU047. Pinned by 675_003–007; 675/665/690 ranges green including
armed witness-oracle legs. Still proposed below: the prover reader —
this pass validates declarations only, no judgment is issued yet.*

*Update (same tree, uncommitted): the prover reader LANDED —
`pass-claims-check` now issues a judgment. For `terminates` on a
`#L`-fold subject it harvests arm guards (produce-position → constraint
text via `splitLinCmp`), back-edge jump args as the rank substitution,
and checks two entailments through a spec-side engine: `linFeasible`,
FM elimination over normalized rows, moved up from refine's `linCheck`
and **integer-tightened** — a strict row `Σc·x < b` over integer fields
loads as `<= b-1`. Real-FM alone found a fractional countermodel to the
canonical loop (`i=0, limit=0.5` satisfies `i < limit` while
`limit-i-1 < 0`); integer domains are all refine/claims judge, so
tightening is correct, and it is what turns `limit - i` provable.
Decrease: `meet(guard, post-bindings) ∧ rank' >= rank` infeasible.
Bounded: `meet ∧ rank' < 0` infeasible. Verdicts `proven` / `unproven` /
`outside-P` (impl shapes the reader can't see: immediate impls, flows
without a fold). 675_003 pins `proven`, 675_008 pins `unproven`
(stagnant rank `i`), 675_009 pins `outside-P`; 675 range 9/9,
671+690_3*+665 150/150 with the tightened engine. Goal absorption isn't
checked — `terminates` has no goal; `honors` will need it.*

The transcript's conclusion, restated as work: koru's missing piece for a
law-proving surface is not a prover — it is a **leaf refutation with a
home**. `std/refine`'s fold already is a confluent meet with loud
empty-meet refusals; `std/realize` already commits admission verdicts as
decidable mark relations; `std/spec` already harvests typed sites; the
witness pass already runs the verdict trichotomy. Four surgical changes
turn those four libraries into one law lane. A fifth section says what
stays out.

## 1. `std/refine` — one fold, N readers, one of them the prover

What exists (`refine.fold.kz`): `walkRefine` folds every `std/refine`
block and every landed `facet_decl` onto one name-keyed meet —
`lo`/`hi`/`eq`/`clamp`/`alts` atoms, `*_conflict` slots that surface as
KORU205. Three readers share it: the transform mints the `facet_decl`,
the explainer re-derives the report, consumers call `metFields` at their
boundary. The meet is already the leaf refutation gdp-wired's kernel
runs per case — an empty meet *is* the refutation, and absorption *is*
implication.

The surgical change is a fourth reader:

- **The prover reader** — a `[comptime]` tor that runs the same fold
  induction-shaped: seed the meet at the base (init fields' facets),
  apply the step's transforms onto the meet (each refine atom over a
  transformed field re-joins), check the goal atom absorbs into the
  n+1 meet. Absorbs → induction holds; step-meet empty under the law →
  refuted, and the failing constraint names the witness. One fold
  means the prover cannot disagree with the runtime checks — same
  `metFields`, different judgment.
- **One new atom constructor** — the v0 fold is per-field: intervals
  on `port`, sets on `role`. Step laws are *relational* — "spend stays
  within `b + m`" relates two fields, "balance only goes down" and
  `x' = x + 1` relate a state pair. A linear combination over 2–3
  fields (`a + b <= c`) is the smallest extension that expresses them.
  Still a monotone meet;
  the cost is small-matrix reasoning at leaves — Farkas certificates,
  gdp-wired's exact leaf shape. *(Landed — see the status update; the
  leaf is Fourier–Motzkin with witness masks, real-complete and
  sound-refusal-only over the integer gap.)* Disjunction stays queued
  behind it (`refine.k` already lists `*a | b` as next; a disjunction
  is a case split, each branch a meet you test for emptiness).
- **Absorption receipts as facet data** — the `[comptime|transform]`
  tor emits the prover's verdict the way it emits every other layer's:
  typed data in the AST (`facet_decl`-shaped), not prose. A `proven`
  stamp then points at the receipt as its standing instrument;
  `instrumented-stamps-resolve` already refuses the day it rots.

What this is NOT: a general symbolic evaluator. The step transform
itself is a flow, and folding atoms over an arbitrary flow's field
transformations is the hard boundary — the prover reads the fragment,
and the fragment is named below.

## 2. `compiler:emission` — the overwritable tor is a realize row

What exists: `compiler:emission`'s arms now consult declared
`std/target` rows (`auditTargetArm`, drift-logged, arm wins during
migration); `emit-*` chains return the row's `artifact` field;
`target(zig|js|cs|c)` rows carry `facet`/`artifact`/`toolchain`.

The surgical change is one interface row:

- `iface = "std.emit:c"` (the machine-semantics interface), `binds`
  naming the mechanism (the emission impl the `|variant` channel
  selects). Realize's admission solver then answers one question —
  *can this program emit to this arm?* — and the arm matrix's empty
  columns make provider gaps visible before anyone spends a compile.
  The overwritable tor stops being a special hook; it is the mechanism
  the binding names.
- `evidence` already carries the `V:` grade convention; wire it to the
  manifest stamp vocabulary: an emission arm stamped `proven` names
  its standing instrument (its alive2 cell, its witness corpus) and
  `instrumented-stamps-resolve` enforces it forever. "Proven when
  typed" becomes a mechanical read, not a slogan.
- **Congruence is the arm's first claim family.** An emission arm's
  guarantee is *congruent-with-the-Zig-lane over its fragment* — K1's
  stdout equivalence is that claim already running. Where the lane
  can't fail loudly it inserts a `?!violated` guard; where it can't
  even guard it names a refusal. The claim/route/stamp vocabulary of
  §4 is how the arm *declares* all three.
- **Override exclusivity, measured not assumed**: two `|fpga` impls
  from different modules must refuse with the same volume as
  realize's `duplicate-arm`. `|variant` refuses undeclared tags
  (KORU122); declared-and-twice must be equally loud or the channel
  reintroduces the last-wins hazard the fold's empty-meet refusal
  deleted.

## 3. `std/realize` — the ledger is the certificate

What exists: `row`/`arm` as `[comptime|norun]` sites harvested via
`spec.sites()`; `mergeDecl` refuses duplicate arms and contradictions;
verdicts commit as marks whose `kind` names a decidable relation
(`admission`, `declaration`, `catalog`, `projection`) — the domain rides
`site`/`payload` as data.

The surgical change is closure of two holes, not new machinery:

- **Sunset the host-line fallback.** `collectRows` still honors
  `const realize_row = .{...}` smuggled in host lines — a declaration
  the harvester cannot type is a hole in spec independence (the
  winning-is-possible lesson: a contract a consumer can modify without
  touching the spec file). The typed `~std/realize:row` site becomes
  the sole grammar; the fallback gets a refusal date.
- **Migrate prose fields toward atoms where they carry obligations.**
  `Row.stack: u64` is checkable; `resources`/`mechanism`/`deltas` are
  honest-but-opaque strings — fine as catalog data, dead as proof
  payload. The day a binding must *participate* ("this mechanism
  preserves the flow's invariant"), the fields it names need the
  refine treatment: atoms in the decidable fragment.
- The Lean twin's job degenerates correctly: not "re-execute the Zig"
  but "check this ledger against a declarative model" — every admitted
  site has a binding for its arm, every refusal is documented. That is
  gdp-wired's trust shape: tampered trees compute to false.

## 4. Participation — the module story

What exists: every voice a module already speaks is one opt-in
surface. Explain is `[comptime|explainer]` tors a shared gather
invokes; witness is `enforce` + marks; realize is `[norun]` sites
through `spec.sites()`; repo-level claims are `std/invariants` rows.
Law claims slot in as a fifth surface of the same shape — and the
qualifier already exists: `std/spec` owns the contract vocabulary
(`ScopeEvent` descriptors, `spec.revision`, the `sites()` harvest). A
claim is the missing "guarantees" column of `ScopeDescriptor`, so the
tor is `std/spec:claim` — a separate `std/law`/`std/proof` qualifier
would split contract data across two libraries, the exact seam the
winning-is-possible doc warns about.

**Where claims live: the `.k` file.** `file_types` already rules `.k`
as the pure contract facet — "events, types, obligations, no proc
bodies" — and a law claim IS contract data. No LAWS.bend-style
separate file, no new extension: the module's `.k` is its spec file,
which is the winning-is-possible inversion done right — self-
contained, closing over registered vocabulary, sitting in the same
module the consumer builds against.

**The site shape** (realize's precedent — the name is the arg, the
payload is the JSON body):

    ~std/spec:claim(atom: settles-once) {
        "judgment": "at-close",   // per-fire | at-close
        "route":     "decidable", // decidable | guard | trusted-base
        "stamp":     "proven",    // manifest grades + instrument ptr
        "arm":       "fpga"       // optional — absent = universal
    }

- **Atom as arg — ruled** — `claim(atom: settles-once)` mirrors
  `row(iface: ...)`: the name is the resolvable identity, checked
  against the registry at harvest; an unregistered atom is a named
  refusal riding the `signal-vocabulary-stays-defined` discipline.
  The rejected alternative — `"atom": "settles-once"` inside the JSON
  body — is realize's `resources: string` seam again: an opaque string
  carrying an obligation, checkable by nothing.
- **Atom semantics live in `std/spec`** — each registered atom carries
  its spec-side definition over the transition vocabulary, so two
  modules' `settles-once` cannot mean different "once"s. LAWS-
  independence made structural, not a gate row bolted on.
- **Arm scope as a field — decided** — `"arm": "fpga"` inside the
  body is data, matching realize's precedent (arm names are already
  JSON data in rows). `|variant` on a norun site would be a new
  semantic for the glyph — there is no impl to select — so it stays
  out unless Lars rules it should keep its scope reading there.
- **Routes factor once** — `decidable | guard | trusted-base` is
  refine's split and the witness trichotomy
  (`lossless`/`deferred`/`refused`), re-exported rather than invented
  a third time.
- **Temporality is a field** — taps witness lines are per-fire;
  custody lawfulness (`HoldsCheck`) is at-close over the log. Both
  exist; `settles-once` is meaningless until it says at-close.
- **The fourth voice.** Explain says what it decided; witness says
  what it did; proof says what it guarantees — *realize says what
  serves it*. A claim without its arm scope is the unfixed
  `LAWS.bend`: a guarantee the consumer assumed and the spec never
  promised.
- **The producer side: passes publish descriptors.** Participation
  needs a declared surface to bind to. A compiler pass should carry
  its `ScopeEvent`-shaped descriptor — the AST shapes it consumes,
  the refusal branches it can take, the obligations it creates.
  Today's counterexample is the emitter's string hygiene: the
  emitted-while invariant is a regex over emitted *text* only because
  the emitter never declared that surface. A claim against an
  undeclared surface can only regex its output — the check's strength
  is bounded by the producer's silence.
- **First cross-module consumer: the spec-diff harvester.** A
  `[comptime|command]` consumer diffs harvested claim sites against
  the previous revision blob and derives the bump tier — law removed
  → major, added → minor, else patch — and the git-gate refuses a
  major committed as patch. Participation's first external demo:
  semver as a computed verdict, not a mood.

## 4.5 The decidable fence — `P` and `P_REFUSES`

Two fences, not one — the distinction matters. `FlowKernel`'s header
already names the *evaluator* fence ("What is NOT modeled": effects,
stores, destructured arms, `Source`, `fragment`, function calls,
nested labels, module paths, i64 wrap) — the set `run`/`evalE` can
re-decide at all. The prover's fence `P` is a strict subset of that:
the fragment over which atoms absorb into the meet, not merely terms
that evaluate. A claim outside `P` is not a failed proof — it routes
to `guard` or `trusted-base`, which is the participation record's
reason for existing.

**`P` — the decidable fragment** (what the prover may read):

- **Atoms**: the fold's v0 vocabulary (`lo`, `hi`, `==N`,
  `clamp(lo,hi)`, `alts`) plus the linear constructor
  `a + b <= c` over 2–3 fields.
- **Values**: `int` (unbounded — the kernel models no wrap), `bool`,
  `str` under equality and `alts` membership, `cell` records as the
  field-carriers the atoms name.
- **Step-transform expressions**: the `evalE` subset restricted to
  linear form — `lit`, `var`, `field`, `+`/`-`/`*` by constants,
  comparisons, `and`/`or`/`not`/`cond`, and the int builtins
  (`intCast`, `divTrunc`, `rem`, `mod` — which are int ops with
  decided-by-name arities). Guards live in the same boolean fragment.
- **Flow shapes**: tag dispatch, `#label` folds whose back-edge jump
  args credit discharges — the cyclic shape the rank discipline
  checks. Residue arms bound by the render subset (print/print.ln
  invokes, `{{name}}`/`{{name:spec}}` holes naming bound
  identifiers).

**`P_REFUSES` — named refusals, each a graduation not a failure:**

- Non-linear arithmetic — `x * y`, `div`/`mod` by non-constants.
- Floats — no lawful linear rendering (`renderVal` already refuses;
  `%g` is not a decided representation).
- Strings beyond `alts`/equality — `concat` produces a value the
  linear core cannot bound.
- Array indexing in obligations — the theory of arrays is a different
  decider, queued.
- Everything the evaluator already refuses (effects, stores,
  destructured arms, `Source`, `fragment`, calls, nested labels) —
  these cannot even be *claimed*.
- Destructured/catchall arm metatypes in the prover's path.
- `{{expr}}` format holes — bound-identifier holes only.
- A cycle with no decreasing rank — the prover answers `unproven`,
  it does not search forever.
- `*a | b` disjunction — queued behind the linear constructor; a
  case split over meets, not silently absorbed.

The verdicts are three: `absorbed` (proven — receipt emitted),
`refuted` (the failing constraint names the witness), `outside-P`
(named constructor, routes to guard or trusted-base).

## 5. What stays out, on purpose

- **The institution layer** (contract graph, divergence objects,
  role-separation tables from the transcript's first half) presumes
  the evidence machinery already trusted. K1–K4 + this lane *are* the
  machinery; the governance shape returns when there is something to
  govern. Parked, not repudiated.
- **GPU/bounded falsification search.** For broken variants,
  falsifier-first ordering is already measured wisdom from the
  gdp-wired spike (search found the break instantly where the prover
  ran 5+ min). Exhaustive bounded search over small domains covers
  early laws; the existing forged/drift corpora discipline is the
  harness shape.
- **K4 guest channel.** When `proof:` lands, the guest checks
  *evidence* — a checker run over committed corpora, journal bound to
  artifact digests — not "the battery ran." The receipt attests an
  evidence-producing computation, never correctness-in-general.

## Sequencing

1. **`310_142` c-refine leg** — the standing armed failure; the
   kernel's flat-body subset can't render `{{ v:d }}` residue splices.
   Small, teaches the residue channel, and returns the armed battery
   to all-green.
2. **The decidable fence** — name which atoms, comprehension stages,
   cell shapes the prover may read. Same refusal discipline as
   `C_REFUSES`: `P_REFUSES` names the boundary, refusal is graduation,
   not failure.
3. **The kernel rung** — the prover reader over the fenced fragment:
   case splits + meet-refutation leaves + rank discipline on label
   folds (a fold's back-edge crediting discharges is already cyclic
   with rank). "One-loop prover for the linear core, synthesize-or-
   refuse past it" — per the spike's measured strengthening wall.
