# The Concordance Matrix

The third matrix — provenance and CS-canon mapping for every surface
noun/verb the language mints. `refusal-matrix.md` projects refusal
sites; `obligation-matrix.md` projects obligation behavior; this one
registers **vocabulary itself** — where a term entered, what existing
CS term it shadows, and whether the coinage is warranted.

Companion wall: `deslop-koru-libs.baseline` `spellings=` pins *drift*
(new surface in corpus). This matrix pins *provenance* (where a term
came from and whether canon already had a word). Drift without
registration is the alarm.

**Gate (proposed):** a PR that adds a surface noun/verb must cite an
existing row or append one. The ruling column may stay `unplaced` —
registration may not.

Ruling values: `canon-alias` · `warranted neologism` · `unplaced`
(proposed rulings marked `(p)`; Lars rules).

## 1. Grammar core — verbs the user spells

| term | first minted | nearest canon | delta | ruling |
|---|---|---|---|---|
| `use` | language core | `import` (module) | also declares the module's host variant set | canon-alias (p) |
| `tor` | language core | function / procedure | outcome-typed: returns named branches, not values | warranted neologism (p) |
| `proc` | language core | builtin / intrinsic / extern fn | host-provided primitive; the spelling under it is the host lane's | warranted neologism (p) |
| `subflow` | language core | lambda-inlined subroutine / outline region | a named control subgraph joined back into its caller's flow | warranted neologism (p) |
| `flow` | language core | CFG region / basic-block graph | Koru's is the *elaborated* graph — post-transform, pre-emission | canon-alias (p) |
| `arm` (`\| x`, `! x`) | language core | case alternative / match arm | two distinct kinds: `\|` outcome arms, `!` reactive/interceptor arms | canon-alias (p) |
| `branch` | language core | named result / tagged return value | a tor's result is a *labelled* union member, not a position | warranted neologism (p) |
| `label` (`#x`) / `join` (`@x`) | language core | loop label / join point | `#` names a control point, `@` repeats or exits it — goto-shaped, flow-bounded | warranted neologism (p) |
| `stop` | language core | early return / break-to-result | returns a branch payload from inside a construct | canon-alias (p) |
| `for` / `each` / `! each` | language core | counted loop / for-each / reactive each | `! each` is an interceptor family, not iteration over data | canon-alias (p) |
| `take` / `insert` / `discharge` | std/store | get-and-remove / put / dispose | custody verbs: `take` mints an obligation, `discharge` settles it | warranted neologism (p) |
| `stored` | std/store | assignment / mutation | plural-write envelope with per-field addressing | canon-alias (p) |
| `query` | std/store | filter+map / comprehension | branch-typed result (`\| row`, `\| item`, `\| full`) over a plural store | warranted neologism (p) |
| `sweep` | std/store | scan / fold-over-rows | iterates live rows with interceptor triggers | unplaced |
| `watch` / `interceptor` / `rule` | std/store | trigger / hook / rewrite-rule | comptime-transplanted into write paths (qbody transplant) | unplaced |
| `claim` (`! ...` binding head) | impl-override family | capability assertion / assume | cross-module custody assumption — "the callee will settle it" | unplaced |
| `strict` (`[strict]`) | witness arc | checked mode / contract gate | opt-in refusal for unproven or rounding writes | canon-alias (p) |
| `comptime` | language core | compile-time eval / staged computation | Zig-derived spelling; whole compiler passes run under it | canon-alias (p) |
| `transform` | language core | macro / rewrite pass | AST-to-AST pass declared in-language | canon-alias (p) |
| `host` / `variant` (`\|zig`, `\|c`) | language core | backend / monomorphization target | per-tor host bodies selected at emission | warranted neologism (p) |
| `facet` | emitter internals | target-specific codegen arm | internal, not user surface | unplaced |
| `?!name` (panic branch) | 830_* cluster | exception / `unreachable` | an obligation to *handle or declare*, not to discharge | warranted neologism (p) |
| `marks` (`.marks`) | `ast.zig:1619` | compiler-internal metadata / attributes | never parsed from surface — grammar-bounded unauthorable channel | warranted neologism (p) |
| `requires` (`[requires("a","b")]`) | `b2673bf54` pass graph | `depends_on` / build-requires edge | declarer-side ordering edge on tors (pipeline position) and on `[transform]` decls (stage order). Call-annotation grammar slot — distinct from `std/compiler:requires` the directive tor (build deps), same word two slots: Lars rules | canon-alias (p) |
| `preserves` (`[preserves("kind",...)]`) | `430c9cd8d` pass graph rung 2 | LLVM `PreservedAnalyses` / analysis-preservation set | blast-radius bound: top-level `ast.Item` kinds a transform write-back holds invariant; `!kind` atoms invert ("all except"), KORU181 enforces | canon-alias (p) |
| `!kind` atom | `430c9cd8d` pass graph rung 2 | set complement / negated atom | inside `preserves` only: "every item kind EXCEPT the named ones" — closed under future Item-union growth | warranted neologism (p) |

## 2. Obligation vocabulary

The composite "**phantom obligation**" decomposes into two canon
halves: *phantom* is already canon (Haskell/ML phantom type parameter —
a type-level tag with no value representation; Koru's `<state>` is
exactly that, `!` flags obligation-carrying states). *Obligation* is
the strict-linearity contract: the value must reach a discharge site,
not merely be useable-once. Nearest canon pair: **typestate**
(Strom & Yemini '86) + **relevant/strict linear type** (substructural —
affine permits implicit drop, Koru does not; cf. Rust ownership but
disposal is *explicit*, no destructor glue). Neither half covers the
other → the composite is a warranted coinage.

| term | first minted | nearest canon | delta | ruling |
|---|---|---|---|---|
| `phantom` (`<state>`) | phantom_semantic_checker.zig | phantom type parameter / typestate | `!` suffix marks obligation-carrying states | canon-alias (p) |
| `obligation` | 330_* cluster | linear/relevant use contract | must reach discharge — no weakening (no implicit drop) | warranted neologism (p) |
| `custody` | `330_*` / custody-edge arc | ownership / resource tracking | explicitly an *interval*: mint to settle, replayable as a ledger | warranted neologism (p) |
| polarity `borrow`/`consume`/`issue` | phantom checker | borrow / by-value / escaping param | `issue` = obligation *leaves* through a declared output | canon-alias (p) |
| `mint` | custody-edge arc | resource acquisition / obligation creation | ledger open edge | canon-alias (p) |
| `held` | `b10de5caf` | borrowed-in obligation / context parameter | contract-seeded debt: enters live, minted at bind time not at a call | warranted neologism (p) |
| `discharge` | language core | consume / dispose / drop | ledger close edge; explicit settle | canon-alias (p) |
| `issued` | `b10de5caf` | ownership transfer to caller (escape) | closes a local interval by documenting the escape — Rust `->` of an owned value | warranted neologism (p) |
| `move` | draft only — never minted | move semantics | dead: the settle paths the draft imagined as `move` shipped as `held` (in) / `issued` (out); per-binding mint/settle model, no transfer op exists | dead |
| `settle` | handoff prose | obligation resolution | umbrella over discharge + issued | canon-alias (p) |
| `leak` / `escape` | phantom checker | resource leak / escaping reference | leak = unclosed interval; escape = closed-by-issue | canon-alias (p) |
| `live` | phantom checker | liveness (dataflow) | same word, obligation-flavored | canon-alias (p) |

## 3. Verification vocabulary (the K-tranche mints)

| term | first minted | nearest canon | delta | ruling |
|---|---|---|---|---|
| `witness` | `std/witness`, witness.kz | certificate / proof object (PCC) | machine-generated, grammar-unauthorable; the artifact the checker trusts | canon-alias (p) |
| `witness-check` | koru-verification-path §3.5 | proof checking / certificate verification | named pass: consumes marks, owns verdicts, never rewrites | canon-alias (p) |
| `obligation-synthesis` | koru-verification-path §3.5 | VC generation + proof-producing solver | realized as `pass-auto-discharge`: rewrites AND mints marks | warranted neologism (p) |
| `auto-discharge` | auto_discharge_inserter | drop elaboration (Rust MIR) / scope-bound cleanup insertion | solver-inserted disposals at flow exits | canon-alias (p) |
| `custody-edge` | `b10de5caf` | ownership-transfer event / ledger entry | corpus-level replayable ledger — Lean re-decides balance | warranted neologism (p) |
| `enforce` | `std/witness` | lint gate / opt-in checking mode | presence injects the check pipeline; no "don't check" spelling exists | canon-alias (p) |
| `verdict` | WitnessCheck.lean | judgement / check result | per-site ruled outcome; `verdict`, not `pass` | canon-alias (p) |
| `census` | witness arc | coverage/statistics summary | `[witness] kind: counts` tail lines | canon-alias (p) |
| `deferred`/`lossless`/`rounds` | stored-write-numeric | incomplete / provably-safe / requires-check | narrowing verdicts: deferred = solver can't decide | canon-alias (p) |
| `sole`/`preferred` | auto-discharge marks | unique-match / priority-picked | resolver verdicts over the candidate set | canon-alias (p) |
| `unauthorable` / `forgeable` | callsite draft N3 | not constructible in object language | enforced by grammar (`.marks`), not policy | warranted neologism (p) |
| `candidate-set` | auto-discharge | feasible solution set / candidate enumeration | solver-reported list; completeness needs decl data (open) | canon-alias (p) |
| `ledger` | 699_*/810_* test ledgers → custody arc | transaction/event log | the replayable record an oracle re-decides (`custodyBalance` is its checker) | canon-alias (p) |
| `transform-app` | `459d2e9f2` K2 Use B | rewrite-application record / patch log | per whole_program write-back: site digest + multiset diff of top-level item digests | canon-alias (p) |
| `wp` / `gc` | `459d2e9f2` K2 Use B | whole-program splice / dead-site collection | transform-app verdicts: `wp` = write-back committed, `gc` = comptime-only site removed (singleton) | canon-alias (p) |
| `descriptor` / `descriptor-scope` | `e608264db` | declaration-surface record / scope census | per-event emitted claims (`dis:`/`cr:`/`in:`/`br:`) the oracle re-derives from `decl` and set-compares | canon-alias (p) |
| `rm=`/`add=` (`rmk=`/`addk=`) | `459d2e9f2` / `430c9cd8d` | removal/addition multiset (k: kind tags) | digest sets of top-level items a write-back removed/added — the *actual* set the declared bound checks | canon-alias (p) |
| `blast radius` | `430c9cd8d` pass graph rung 2 | blast radius (security/ops canon) | the set of items outside the site a write-back may touch; bounded by `preserves`, enforced KORU181 | canon-alias (p) |
| `obliges` (`[obliges("pred",...)]`) | obligation rung | proof obligation / decidable contract | closed vocabulary of claims a transform's write-back must satisfy; KORU180 refuses unknown preds + non-transform decls, KORU182 refuses violations unconditionally | canon-alias (p) |
| `kind-stable` | obligation rung | sort-preserving rewrite / type-stable patch | collateral rm/add top-level kind multisets must agree (site licensed): no top-level fabrication or silent deletion | warranted neologism (p) |
| `matched-only` | obligation rung | justified-touch / callsite-only consumption | every removed non-site item must contain an invocation the transform fires on: no silent consumption of unrelated items | warranted neologism (p) |
| `transform-oblige` | obligation rung | obligation-evidence record | one witness line per declared obligation per application, carrying the evidence the oracle needs to re-decide (site digest, kind multisets / justified set) — verdict never trusted | canon-alias (p) |

## 4. Known drift risks — watch these

- **`move`** — dead: draft vocabulary, the real settle paths shipped as
  `held`/`issued`. Kept as a row so nobody re-mints it.
- **`obligation` vs `!` arm** — `!` arms (interceptors) and `<state!>`
  (obligation states) share a glyph but are different constructs;
  concordance treats them separately (grammar table).
- **`custody` vs `ownership`** — if Rust/CS `ownership` suffices,
  `custody` is an alias; the interval-ledger reading may warrant the
  coinage. Lars rules.
- **Layer ordinals are doc vocabulary, not filesystem names** —
  `K1`–`K4` name architecture layers in `koru-verification-path.md`;
  concrete artifacts take boring names (`verify/witness/`,
  `WITNESS_CHECK`, `KORU_WITNESS`), not `k3/`, `K3_WITNESS`, `KORU_K3`.
- **Misregistration precedent** — `attendant` was seeded from session
  memory with zero tree hits and removed; a concordance row is a claim
  about the tree, verify before registering.

## 5. Gate mechanics (proposed)

1. New surface noun/verb in a diff → append a row (any column may be
   `?`, but `term` + `nearest canon` must be attempted).
2. `unplaced` rows accumulate under §4 until ruled.
3. The `spellings=` baseline catches unregistered growth; this matrix
   catches registered-but-unjustified neologism. Two walls, two axes.
