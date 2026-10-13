# c-lane — return handoff (2026-10-12)

## Checkout topology (the bridge discipline)

Two independent clones, not worktrees — nothing propagates on its own:

- **`/home/cypoe/src/koru-ccomp` (WSL ext4)** — the work site. All edits,
  `zig build`, the regression suite, and `git commit` happen here. The
  suite cannot live on `/mnt/w`: a `git status` enumeration there costs
  ~52s vs instant on ext4, and backend-cache stat semantics get fuzzy.
- **`W:\src\koru` (Windows/NTFS)** — editor checkout + native
  `koruc.exe` build + the push bridge (WSL DNS cannot reach github).

The bridge between them, per tranche:

1. Commit on WSL (`Fabian Schindler <39304197+Cypoe@…>` author,
   `Co-Authored-By: Devin` trailer — the convention through `81fe5c598`).
2. From the **Windows side**: `git fetch //wsl.localhost/Ubuntu/home/cypoe/src/koru-ccomp ccomp`.
3. `git update-ref refs/heads/ccomp <sha>` — moves the branch without a
   checkout (that's why W:'s worktree lags its own HEAD until step 4).
4. `cp` the changed files into the W: worktree so the editor sees them.
5. `git push https://github.com/Cypoe/koru.git ccomp` from Windows.

EOL state: repo blobs are LF. Both checkouts now run `core.autocrlf
true` — CRLF worktrees are converted on compare/commit, which is what
silences W:'s ~8.7k-file phantom diff. Files `cp`'d between checkouts
keep their stat records confused on drvfs ("needs update" that survives
`update-index --refresh`); `git checkout HEAD -- <file>` rewrites the
stat record cleanly when content is already identical.

Branch `ccomp`, commit `900769b60`, 1 commit of session work on top of
`verify-path`'s tip (`bd6dc5638`). This note is the map; the measured
detail sits in the appended "Measured (session 3)" section of
`koru-c-lane-test-plan.md`, and the transform-consumption finding has
its own concept frag. Second pair of eyes wanted on the *detection
choices*, not the lane itself — the four cells are green.

## Demonstrated, not asserted

- `koruc input.k --lang=c` → `output_emitted.c` → `ccomp -O
  -fstruct-passing -Wl,-s` → run → stdout byte-identical to the zig
  lane. Driven end-to-end through `run_regression.sh`:
  `400_212_c_transducer_equiv` PASS.
- Three refusal cells PASS, each naming its pinned axis (KORU047,
  located, `C_REFUSES` substring-matched): `400_208` raw host lines,
  `400_209` `!` effect arms, `400_210` concurrency.
- Multi-axis refusals name every co-present axis — C2's "name all"
  recommendation, implemented rather than ruled.
- `zig build` clean on Windows (zig 0.15.1) and WSL; `zig build test`:
  426/440 pass, the 2 failures are `expression_codegen_compile_tests`
  (initial-commit vintage — they spawn `zig` via `Child.run` and die in
  the build runner's env; pass standalone. Pre-existing, untouched).

## What was built

- `src/c_emitter.zig` (~977 lines) — sequential-fragment whole-program
  emitter. Census first, emission second: `axisRefusalItems` walks the
  entry-module items and flags every applicable axis before a byte is
  emitted. Emits event fns, `immediate_impl` call+bind, `inline_body`
  splice; `NoCProcBody` is a named error class at the point of meet.
- `codegen_utils` — `HostTarget += .c`, `lowerCInto`. Shared lowering,
  one expression vocabulary: `++`→`__koru_concat`, `and/or/not`,
  `.len`, `if (c) a else b` via the shared `jsInlineIf` scanner
  (parametrized by target — the C ternary is spelled identically).
  `@builtins` refuse by name.
- `koru_std/io.cprec.kz` + `ioLowerCExpr` + `~part cprec` — the
  `print.ln|c` transform family, twin of jsprec/csprec; reroutes to
  `print.impl` for shape checking, `inline_body` carries the C text.
- Plumbing — `compiler.kz` c_emitter module + `"c"` dispatch arm;
  `main.zig` `output_emitted.c` filename, skip Stage D, C-specific
  completion message naming ccomp. `enforceLangNamespace` admits `c`
  — and `cs`, which was a registered emitter absent from the list
  (unrelated wart, fixed in passing; `220_050` pins `--lang=rust`,
  unaffected).

## Detection choices — where eyes would help most

- **Concurrency is presence-scoped, not use-scoped.** Transforms
  consume their call sites: `std/pump:create` never reaches the
  emitter as an `.invocation` (the flow is rewritten wholesale). The
  census reads merged `module_decl` presence (`std.pump`, `std.rings`,
  `std.threading`→worker) instead. `import std/pump` without ever
  pumping refuses. That is stricter than the axis as worded — sound,
  but it conflates "imports the machinery" with "uses it". If
  use-scoped precision matters, it must be measured pre-transform —
  in a pass, not in an emitter. New concept:
  `frag-a-transform-consumes-its-call-site`.
- **`!` detection rides surviving continuations**, not declarations —
  effect arms transplant into `impl_of` flows, so the resumable axis
  fires on continuation kind. Anything `!`-shaped the transform
  *doesn't* preserve is a blind spot of the same class.
- **`enforceLangNamespace` grew `cs`** — it was already a wired
  emitter with a dispatch arm; the KORU126 emitter list just didn't
  know. If `cs` should instead stay variant-declared-only, revert
  that half of the edit.

## Known warts

- The KORU047 diagnostic pair prints **twice** — `emit` is invoked
  from two pipeline points and the `catch` exit doesn't dedupe.
  Cosmetic (pins are substring matches), but a user-facing double
  diagnostic is the kind of thing that erodes trust in the refusal
  table's precision. Worth a look.
- `HostShape` switches carry no `.c` arm — lazily analyzed, so a
  future `.c` caller hits a compile-time error naming the missing
  arm rather than a wrong shape. Deliberate, but if you'd rather
  have `.c => unreachable` + comment, mechanical change.
- The stale empty `400_209_c_resumable_refuses` dir in the WSL clone
  predates this session; the committed cell is
  `400_209_c_effect_arms_refuse`. Untracked clutter, not a conflict.

## Still open (status, not new questions)

- **C1** (`!`-arm eligibility classes) — partially answered by
  implementation: resumable pairs refuse on the axis; transplanted
  arms reach the emitter as ordinary continuations and emit fine
  *if* their bodies stay in-fragment. Per-unit eligibility remains
  empirical — the refusal corpus will measure it.
- **C3** (`NoCProcBody` as own axis) — exists as a named error class,
  point-of-meet not census row. If you want it in the multi-axis
  census (listed alongside, not instead of), mechanical.
- **C4** — row-4 leak exemplar still uninvented; `400_211` reserved.
- **C5** — `.kc` facet semantics untouched; no `|c`/`kc` corpus yet.
- **W-questions** (witness surface, encoding, verdict-owner split) —
  untouched this session; `std/witness` scaffold stands as delivered.
- **`enforce` vs `LANGUAGES c`** — both describe the C arm from two
  places; which wins on disagreement is unruled. Recommendation
  stands: `enforce` wins, `LANGUAGES` becomes redundant for c.
- **Missing oracle in CI** — the harness fails `c-oracle` when ccomp
  is absent (per G-CC-2: fail, never skip). CI needs
  `KORU_CC_ORACLE` or a ccomp install to stay green.

## Next milestone per your deflate ruling

The `|c` proc-variant surface (`~proc tor|c`) — the emitter already
refuses `NoCProcBody` by name, and io.cprec shows the transform-side
pattern. That is the smallest increment that widens the fragment
without new language surface: std gains `|c` bodies for the procs the
corpus actually reaches, and the refusal census measures the
remainder.


---

# session-4 addendum — control-flow templates landed (2026-10-12)

First widening tranche, measured against the census (`docs/c-lane-census.md`
"Delta" section has the reprobe table): `for|c`, `if|c`, `const|c` +
the marker resolver they require. Zero `~for`/`~if` `no-c-template`
refusals remain of the 277.

## What the prime sieve now dies on

`NoCProcBody: input:__grid_write_L32_1056` — `std/grid:stored`
(grid.stored.kz:~176) synthesizes a per-site `ProcDecl` with
`.target = "js" else "zig"` — the `lang == "c"` case stamps `zig`.
Fixing it is NOT flipping the tag: the proc body and the synthesized
call's arg text are lowered through `grid_read.lower`, which produces
Zig spellings (`__KoruGridT_{grid}.__koru_wide(...)`, `sieve[i].composite`
on a Zig-minted type). The whole grid/store synthesis path needs a C
lowering story: `grid.new` (the static cell array), `grid_read.lower`
→ C index spellings, `stored`/`sweep`/`store:stored` variants.

## Design notes for the next reader

- `//@koru:file_scope` is a new template flag line (minted by `const|c`,
  resolved by `emitFileScopeBodies` + the emitFlow empty-shell path).
  If a future `|c` template renders module-scope text, mint the same
  flag — do not widen the marker scan.
- The marker resolver intercepts exactly three prefixes
  (`__koru_continue_`, `__koru_inline_`, `__koru_c_refuse_`). All other
  `__koru_*` tokens are prelude runtime names — the prelude, not the
  scanner, owns that namespace.
- `governed` in `axisRefusalSite` is the transplant test: parent
  `inline_body != null` ⇒ children `!` arms are template vocabulary.
  It deliberately does NOT inherit past the direct parent.
- `io.cprec`'s `{{ x:spec }}` routes on the spec (`d`/`f`/`s`/`S`) —
  `:S` refuses (handle form), `:.N` refuses (no C formatter). The
  `020_021` segfault is a DIFFERENT funnel (arrow-return lowering) —
  still open, still crashes, needs a pinned repro.


## Review questions raised + answered (session 4 tail)

**Port basis — js vs cs emitter.** The marker-resolution contract is one
contract shared by all three emitters (the Zig reference is
`emitter_helpers.zig`; js and cs emitters carry the same
`__koru_continue[_bare_]_N` + `__koru_inline_[scoped]_N` scanner
verbatim). Where they differ is host *rendering*, and there C sits on
the C# side: the splice binds a typed local (`long long i = arg`, the
fragment's int spelling — `for|c` only mints splices for counted
ranges), and destructured bindings refuse rather than emit payload
temps. One wart found while comparing: cs_emitter.zig:2133's comment
still says "the vertical refuses these (effects are unmodelled)" —
stale; the code below it implements the splice. Cosmetic, but it
misstates the contract for the next reader.

**Ordering — should K3 (Lean) come before K1 finishes?** No, and the
reason is what each layer certifies. The bugs the census keeps
surfacing (zig-stamped synthesized procs, un-emitted domain types) are
emission *coverage* gaps — the instrument for them is the oracle plus
the equivalence cells, which is exactly what ccomp is. A Lean model of
the emitter would not catch them faster than `ccomp | run | diff`
already does, and would be a bigger artifact than the emitter.
K3's actual scope — a verified checker for obligation *verdicts* — is
orthogonal to C emission and gates nothing today; it stays a parallel
track. If a small formal model is wanted, the honest candidate is the
marker-resolution/drain contract itself (consumed-mask ⊆ continuations,
no terminal dropped), as a K3 warm-up — not a prerequisite.

**Surgical fixes status.** `020_021` (the census's segfault exemplar)
now PASSES — `42` byte-identical — the `:d` spec routing closed that
instance of int→pointer. Still open: (a) domain/record types declared
in non-input modules never reach `output_emitted.c` (10 dirs, mostly
`665_PROTO`); (b) bare (non-`{{ }}`) print args still funnel any type
into `const char *` — the header comment claims "the oracle's
typecheck refuses" but ccomp only *warns* and the binary segfaults, so
that gate is weaker than documented. Right fix when it matters: refuse
non-string-literal bare args by name.


## Session 5 — grid/store synthesis landed; the sieve is the acceptance cell

**`NoCProcBody` is cleared.** `2105_prime_sieve` now runs under
`LANGUAGES: zig c`: ccomp (`-fstruct-passing`, the pinned flag) compiles
the emitted C, the binary prints `78498`, byte-identical to
`expected.txt`. The previous wall section above (grid.stored stamping
`.target = "zig"`) is resolved — all synthesized units now mint a `|c`
variant when `CompilerEnv.lang == "c"`:

- `grid.new` — C arm emits a static struct cell at file scope
  (`static struct { long long composite[1000001]; } __koru_grid_sieve = {{0}};`),
  `__koru_grid_<g>_size`, and a per-grid `__koru_at_<g>` bounds helper.
- `grid_read.lower` — `.c` arm lowers `sieve[i].composite` to
  `__koru_grid_sieve.composite[__koru_at_sieve(i)]` (flat member access,
  no Zig `&`/type-name spellings).
- `grid.stored` — write procs mint `.target = "c"` with a C lvalue body.
- `grid.sweep` — mints a counted `for` calling the body event through
  the emitters


## Session 5 — grid/store synthesis landed; the sieve is the acceptance cell

**`NoCProcBody` is cleared.** `2105_prime_sieve` now runs under
`LANGUAGES: zig c`: ccomp (`-fstruct-passing`, the pinned flag) compiles
the emitted C, the binary prints `78498`, byte-identical to
`expected.txt`. The previous wall section above (grid.stored stamping
`.target = "zig"`) is resolved — all synthesized units now mint a `|c`
variant when `CompilerEnv.lang == "c"`:

- `grid.new` — C arm emits a static struct cell at file scope
  (`static struct { long long composite[1000001]; } __koru_grid_sieve = {{0}};`),
  `__koru_grid_<g>_size`, and a per-grid `__koru_at_<g>` bounds helper.
- `grid_read.lower` — `.c` arm lowers `sieve[i].composite` to
  `__koru_grid_sieve.composite[__koru_at_sieve(i)]` (flat member access,
  no Zig `&`/type-name spellings).
- `grid.stored` — write procs mint `.target = "c"` with a C lvalue body.
- `grid.sweep` — mints a counted `for` calling the body event through
  the emitter's `input___grid_body_L40`/`struct ..._in` convention.
- `store.new` (singleton path) — flat cell
  (`static struct { long long n; } __koru_store_acc = { .n = 0 };`) +
  ONE direct `|c` write proc dispatching on the field index. No
  apply/impl named-branch flow; the apply event decl still mints so
  `stored`'s drain probe and `storeAllNames` keep resolving the store.
  Watches/interceptors/dischargers refuse by name (KORU161).

**Two surgical fixes this tranche surfaced:**

1. `retain` seeds reachability. `__grid_sweep`'s raw C loop text calls
   the body event, but raw host text is invisible to AST reachability —
   the event never emitted and ccomp refused the implicit decl. The
   emitter now seeds `reached` from `@koru:retain`-annotated events
   (the same flag dead_strip already honors).
2. `acc.n` lowering ordering — a real bug, fixed surgically. The first
   C arm in `store.new` returned before the transform's whole-program
   `Walk.items` rewrite ran, so `acc.n` inside the `{{ acc.n:d }}`
   interpolation payload stayed raw while the cell declared
   `__koru_store_acc`. The C return now sits after the walk; the fix
   touched nothing else — same appended items (reusing
   `apply_event_item`/`write_event_item`), same semantics.

**Environment note — resolved.** cs-compile fails in WSL only because
no .NET SDK is installed there. Verified on the Windows host
(koruc.exe rebuilt from this tree, `W:	ools\zig-0.15.1`, .NET SDK
8.0.425 installed): `110_022` cs prints `v=42`, `020_021` cs prints
`42`, `2105` zig prints `78498` — all byte-identical. The run surfaced
and fixed three POSIX-isms that broke koruc on Windows outright:
raw `.file` path literals in `emitInvocationMetaFields`,
`std.posix.getenv` (auto_discharge_inserter, std/env, gate.helpers),
and an open `koru.csproj` handle passed to `dotnet build` (MSB4025).
See frag-a-posix-hides-in-the-toolchains-own-paths.

**Unmeasured/next:** plural stores (`store.new` plural path is still
zig-stamped — refuses NoCProcBody by name), watches/guards on C,
row-layout grids, `:.N` precision, `:S` handles, domain-type emission
(the 10-dir `const Health` class).


## Session 6 — plural stores + proto-terminal aliases land; 11 cells green

The plural-store tranche landed two coupled mechanisms:

**1. Proto-terminal aliases — `typedef`, not folding.** `std/proto:f64(Health)`
mints `// proto-terminal Health: f64` + `typedef double Health;` on the C
lane (zig keeps `const Health = f64`; js/cs keep the marker alone, aliases
have no runtime repr there). The emitter scans `// proto-terminal` markers
into an alias table (`seedProtoTerminals`) and `cTypeOfResolved` resolves a
declared terminal to *itself* — the name stays the C spelling at every use
site and the typedef binds it. This is the same registry channel
`SL.TermRef.isDeclared` already read for the other hosts; store columns of
proto-terminal type emit `Health health[CAP];` verbatim.

**2. Plural SoA + insert + query-sweep.** `store.new`'s plural path mints on C:
the SoA cell (`static struct { <ct> <f>[CAP]; ...; long long len; }
__koru_store_<s> = {0};`), the void `__store_insert_<s>` event + `|c` proc
(same statements the zig arm writes: capacity check -> `__koru_unreachable`,
column stores, len bump), and the `__store_apply_<s>` event *decl only* —
`pstore_names` discovery scans apply decls for sibling-store names, so the
decl exists for the probe while a `stored` write that reaches it refuses on
the named branches. The `! query` sweep lowers through `HostShape`'s `.c`
arms (`eventCallHead`/`callArg`/`loopHead`/`typedConstBind`/`cellRead`) in
`store.query`/`store.cols`: per-row binds, `for (long long __koru_si = 0;
...)`, `input___store_sweepbody_*( (struct ..._in){ .f = v } )`.

**Refusal surface (all named, none silent):** rule/preorder sweeps,
lifecycle interceptors/watches, generational handles (take / `| row` /
`[id]` / watch), [tree], owned columns, drain, [entity], char[N],
`std/indexes`, ref() homes, refine facets, non-identifier field names,
non-scalar column types, view sweeps, index lookups, `| row`/`| full`
insert arms (store.insert names them itself rather than letting
`unknown tor __store_insertf_*` leak).

**Three surgical fixes this tranche surfaced:**

1. `storeEventQualifier` needed a C arm. The zig qualifier `main_module.`
   names a zig namespace nothing in C emits; the C emitter flat-mangles
   decls as `<home>_<name>`, so the C qualifier is `home.` through
   `cEventPrefix`. Without it the sweep call spelled
   `main_module___store_sweepbody_*` — a name that exists on no lane.
   115_020 (cross-module sweep, store homed in `app/lib`) is the proof
   cell — `app_lib___store_sweepbody_*` resolves.
2. Impl flows carry `flow.inline_body` too. The print transform reroutes
   `print.ln` -> `print.impl` + sets `inline_body` on the FLOW; the impl
   branch of emitEventBody walked `flist.items[0].body` directly and
   emitted `std_io_print_impl()` — a call to the [norun] stub. Now splices
   like emitFlow (continuations resolved). Any transplanted body that
   prints inside a sweepbody hit this — not an edge case.
3. `[ordinal]` cast was zig-spelled for every non-cs target
   (`@as(i64, @intCast(__koru_si))`) — `store.cursor` now spells
   `((long long)(__koru_si))` for C.

**Acceptance — 11 cells `LANGUAGES: zig c cs`, all byte-identical through
`ccomp -fstruct-passing`:** 690_049 (mixed i64+f64 columns), 690_067
(nested sweep), 690_069 ([ordinal]+[row]), 690_086 (arm binds row),
690_090 (row binding shadows store name), 690_110 (nested outer row
read), 690_113 (rebound name shadows), 690_119 (flattened mat4 vec3
row), 690_124 (rebuild row-by-row), 690_272 (shared Health column — the
proto-terminal cell), 115_020 (cross-module). 690_011 pins the
`| row`/`| full` insert-arm refusal via C_REFUSES.

**Verified:** zig lane byte-identical on all pinned cells (controls);
`store.stored`/take/inserth/apply stay refused by name. cs-compile in
WSL remains the dotnet-not-installed environment gap (proven on the
Windows host last session).

**Census delta (219-dir no-C-type bucket, re-probed same instrument):**
2 EMITTED (665_001 proto terminal, 690_272 shared Health column);
30 moved to named KORU161 refusals — the proto-name dirs unmasking their
real walls (take/entity/owned/view/dotted-leaf); 187 still refuse,
dominated by borrow types (`*X`, ~95 dirs), containers (~31), anonymous
record returns (~66), wider scalars (i128 ~10). The proto-alias class
(~15 dirs) is fully resolved out of the bucket.

**Unmeasured/next:** take/inserth/apply + named-branch dispatch (the
largest single mass — every `stored` write and `| row` site),
watches/guards, row-layout grids, pointer/borrow types (~95 dirs),
containers (~31), anonymous record returns (~66), `:.N`/`:S`.

---

## Tagged lifecycle tranche (this session, HEAD)

Named terminal branches lower to a flat tagged result — the js lane's
 shape, C-spelled: an anonymous enum of
 constants +  + optional  for record payloads. Call
sites with  continuations bind  and
 on ; bindings lower to ,
destructures to member reads; the synthesized panic arm reaches
. Unhandled optional arms fall through .

The plural path mints the full lifecycle on C now: SoA cell (+ hslot
arrays/generation/freelist/ident+gen0 flags *only when* the store issues
handles — 690_333's gate holds), void insert,  (/, exhaustion is a branch),  (), 
(/, swap-remove + generation bump + freelist push), and
the  decl (probe-visible, still refuses on reach).

**Surgical fixes this tranche surfaced:**

1.  indexed-read lowering was  + zig-else — the
    zig method spelling reached C
   verbatim.  arm: ,
   and the cell block mints  mirroring zig's
   two-phase trap — brand/gen mismatch panics *before* , with
    falling to the not-a-handle message.  does not
   flush stdio —  now  first or
   buffered stdout dies with the trap (690_116 prints  then
   the stale message).
2.  had / arms and a zig else —  arm
   emits  (355_012's declined-panic-in-arm fires identically).
3. Auto-discharge names panic arms  even over empty payloads —
   the binding is a no-op in zig; C skips it rather than refusing.

**Acceptance — 22 new cells, all through :**
690_011 (/, C_REFUSES removed — emits now), 690_333
(inserth  + take + lean-gate), 690_116 (stale-handle read trap
+ singleton stored-write), 690_070 (take /), 690_085
( optional), 355_012 (declined panic inside an arm), plus
690_022, 690_074, 690_078, 690_079, 690_080, 690_081, 690_084, 690_088,
690_100, 690_101, 690_192, 690_234, 690_250 (indexed read), 690_256,
690_257, 690_273 — all byte-identical or pattern-matched. 690_336 pins
the rules/drain refusal via C_REFUSES +  in LANGUAGES. Harness note:
the c-equivalence check skips EXPECT_TRAP tests, so 690_116/355_012 carry
the  pin as evidence-of-verification rather than harness coverage.

**Refusal surface (named):** rule/preorder/drain sweeps, lifecycle
interceptors/watches, [tree], owned columns, [entity], char[N],
, ref() homes, refine facets, plural stored-write
( — honest but unnamed, better diagnostic
is future work), effect  arms under tagged calls,  catchall,
 guarded dispatch, wildcard/nested-destructure payloads.

**Next:** plural stored-write + indexed write targets (,
 — the largest remaining mass), apply/, then
watches/guards, then the borrow/container/record-return buckets.

---

## Tagged lifecycle tranche (this session, HEAD)

Named terminal branches lower to a flat tagged result — the js lane's
`{ tag, <branch>: payload }` shape, C-spelled: an anonymous enum of
`<ev>_tag_<branch>` constants + `struct <ev>_res { int tag; <payload
members> }` + optional `struct <ev>_<branch>_t` for record payloads. Call
sites with `| arm` continuations bind `struct <ev>_res __koru_res_N` and
`switch` on `.tag`; bindings lower to `const <ct> <b> = __koru_res_N.<m>`,
destructures to member reads; the synthesized panic arm reaches
`__koru_unreachable`. Unhandled optional arms fall through `default:`.

The plural path mints the full lifecycle on C now: SoA cell (+ hslot
arrays/generation/freelist/ident+gen0 flags *only when* the store issues
handles — 690_333's gate holds), void insert, `insertf` (`| row`/`|
full`, exhaustion is a branch), `inserth` (`| row <handle>`), `take`
(`| item`/`| empty`, swap-remove + generation bump + freelist push), and
the `apply` decl (probe-visible, still refuses on reach).

**Surgical fixes this tranche surfaced:**

1. `store.ixrefs` indexed-read lowering was `.cs` + zig-else — the
   `(&cell.col)[cell.__koru_resolve(h)]` zig method spelling reached C
   verbatim. `.c` arm: `__koru_store_<s>.<col>[__koru_resolve_<s>(h)]`,
   and the cell block mints `__koru_resolve_<s>` mirroring zig's
   two-phase trap — brand/gen mismatch panics *before* `row_of`, with
   `row < 0` falling to the not-a-handle message. `abort()` does not
   flush stdio — `__koru_unreachable` now `fflush(NULL)` first or
   buffered stdout dies with the trap (690_116 prints `took 100` then
   the stale message).
2. `synthPanicBody` had `is_js`/`is_cs` arms and a zig else — `.c` arm
   emits `__koru_unreachable("<ev>: unhandled panic branch '<b>' fired
   at runtime")` (355_012's declined-panic-in-arm fires identically).
3. Auto-discharge names panic arms `_auto_N` even over empty payloads —
   the binding is a no-op in zig; C skips it rather than refusing.

**Acceptance — 22 new cells, all through `ccomp -fstruct-passing`:**
690_011 (`| row`/`| full`, C_REFUSES removed — emits now), 690_333
(inserth `| row k` + take + lean-gate), 690_116 (stale-handle read trap
+ singleton stored-write), 690_070 (take `| item`/`| empty`), 690_085
(`| row` optional), 355_012 (declined panic inside an arm), plus
690_022, 690_074, 690_078, 690_079, 690_080, 690_081, 690_084, 690_088,
690_100, 690_101, 690_192, 690_234, 690_250 (indexed read), 690_256,
690_257, 690_273 — all byte-identical or pattern-matched. 690_336 pins
the rules/drain refusal via C_REFUSES + `c` in LANGUAGES. Harness note:
the c-equivalence check skips EXPECT_TRAP tests, so 690_116/355_012 carry
the `c` pin as evidence-of-verification rather than harness coverage.

**Refusal surface (named):** rule/preorder/drain sweeps, lifecycle
interceptors/watches, [tree], owned columns, [entity], char[N],
`std/indexes`, ref() homes, refine facets, plural stored-write
(`unknown tor __store_write_*` — honest but unnamed, better diagnostic
is future work), effect `!` arms under tagged calls, `|*` catchall,
`| b when` guarded dispatch, wildcard/nested-destructure payloads.

**Next:** plural stored-write + indexed write targets (`__store_write_*`,
`__store_envwrite_*` — the largest remaining mass), apply/`stored`, then
watches/guards, then the borrow/container/record-return buckets.


---

## Stored-write tranche (this session, HEAD)

`stored` writes lower on C now — the same generated event chain zig
uses, no shortcut: `__store_apply_<s>` (field-index switch, one named
branch per column, payload = written value), `__store_write_<s>` as an
impl *flow* whose body is the apply invocation + `| <field> _` no-op
arms (a `|c` proc would hide the call inside opaque text and apply's
decl would never be reached — the flow mint keeps reachability honest
and lands the discard-switch through the tagged machinery for free),
`__store_envwrite_<s>` (one call per multi-field block, `field` rides a
bit mask so every rhs reads pre-state — 690_126/690_251/697_007 pin it),
`__store_announce_<s>` (post-write dispatch; a named no-op here because
watch/interceptor presence already refuses the store), and the
singleton envelope twins (`field: mask, value` per field + no-op
announce). Indexed row-reference writes resolve at the write site via
`__koru_resolve_<s>` — stale handle write traps identically to zig
(690_115 prints `took 100` then the stale message), and a foreign-store
handle is rejected by brand check (690_196).

**Surgical fixes this tranche surfaced:**

1. **The void `insert` never bumped `__koru_hslot_next`.** `c_append`
   carried the hslot mint for insertf/inserth/take, but `cap_text` — the
   void insert built a tranche earlier — never got it. A store fed only
   `insert` minted `[id]`/`store[h]` handles that `row_of` rejected
   (`slot >= hslot_next` == 0). Fourth instance of
   `frag-a-fix-lands-in-one-lowering-path`, its narrowest yet — two
   sibling text builders 60 lines apart, one host. Fixed by hoisting to
   a shared `c_hmint`. (690_246)
2. `store.query`'s `[id]` capture spelled
   `__koru_store_<s>.__koru_handle_of(__koru_si)` unconditionally — the
   host-switch frag's limit case, no branch at all. `.c` arm:
   `__koru_handle_of_<s>(__koru_si)`.
3. `stored`'s envwrite mask arg spelled `@as(i64, @bitCast(...))` for
   every host — `.c` arm emits `0xN ull`. (First attempt used a
   `(long long)` cast; arg text passes through a koru-identifier
   escaper, which underscored the space into `long_ long_` — minted arg
   text is not verbatim.)
4. Singleton C return path dropped `stripe_items` entirely — envwrite /
   announce decls+procs now ride the `c_appended` array (grew 4 → 8).
5. `__koru_unreachable` is `_Noreturn`; apply tails end in a dead
   `return {0}` because ccomp's return-path analysis does not read
   `_Noreturn` (warning discipline, not semantics).

**Acceptance — 51 new `c` pins through `ccomp -fstruct-passing`:** the
stored-write heads (690_115 stale-write trap, 690_092
remove-surviving row index, 690_196 foreign-handle trap, 690_246 `[id]`
intrusive chain + singleton+plural envelopes), the pre-state pins
(690_126, 690_251, 697_007), multi-field blocks (690_043, 690_125,
690_128), chain binds (690_130, 690_131), self/foreign keys (690_048,
690_075, 690_117), sweeps and row-addressed reads/writes (690_076,
690_083, 690_087, 690_111, 690_112, 690_114, 690_118, 690_120,
690_121, 690_122, 690_123, 690_127, 690_129, 690_242, 690_243,
690_244, 690_245, 690_249, 690_339), grids (697_003, 697_004, 697_007,
697_008, 697_010, 697_012, 697_013, 697_014; also 697_001/697_002 trap cells),
the raft/orleans world cells (849_raft_quorum_commit,
851_raft_identity_is_not_linearity, 852_orleans_turn_exclusivity,
855_orleans_stale_read_survives_the_interleave), and cross-module
(115_017, 115_040, 115_044, 115_046) — all byte-identical or
pattern-matched
against zig. Harness note: EXPECT_TRAP cells skip the c-check; their
pins mark verified-by-hand evidence.

**Known boundary — now a wall, not a gap:** minted write args are still
untyped text, but the no-narrowing verdict moved *into the compiler*
(see "Tranche: shared narrowing wall" below). `storedWriteNarrowing`
fires KORU161 in the shared `stored` transform before any emitter sees
the write — identical diagnostic under `--lang=c`, no `.c` emitted.
690_160's pin flipped to the wall's own text (the header invited it)
and carries `C_REFUSES`.

**Core-surface audit (for Lars' review):** verified against
`git diff HEAD~1` — every change this tranche is `.c`-gated emit text:
one `if (host_is_c)` else-arm in `store.query`, five `.c` arms /
host-switched literals in `store.stored`, all `store.new` additions
inside the existing `host_is_c` mint block, one `_Noreturn` keyword in
`c_emitter`'s emitted text. **Zero shared-path changes** — no zig/js/cs
arm moved, no AST contract changed. Honest warts, stated not absorbed:
(1) the apply tails carry a dead `return {0}` — a workaround for ccomp
ignoring `_Noreturn` in return-path analysis, contained in emitted
text, not semantics; (2) minted args remain *untyped text* — the
escaper that ate `(long long)` into `long_ long_` is a symptom of the
same thing 690_160 exposes: transforms mint host syntax as strings, so
every host spelling is a per-site intercept and no typed check can run
on them. A typed/witness-carrying arg would let each emitter discharge
its own obligation (no-narrowing, mask widths) instead of borrowing
zig's — the natural seam for the PCC/prepared-witness work.

**Refusal surface (named):** rule/preorder/drain sweeps, lifecycle
interceptors/watches, [tree], owned columns (+ `__store_fwrite_*`
de-bundle), [entity], char[N], `std/indexes`, ref() homes, refine
facets, drain/stripe verbs, `__store_envwrite_<s>_c<i>` specializations
(the general masked unit covers them; specs are a speed elision, not a
correctness one), effect `!` arms under tagged calls, `|*` catchall,
`| b when` guarded dispatch.

**Next:** watches/interceptors (the announce dispatch point exists —
minting the arms is the tranche), owned-column `__store_fwrite_*`, then
the borrow/container/record-return buckets; K3 Lean scaffold in
parallel.

---

## Tranche: shared narrowing wall + harness refusal legs (session, cont.)

This tranche deliberately crossed the emitter boundary into a shared
path — that is the point, and it is called out here for review rather
than buried.

**`storedWriteNarrowing` (`koru_std/store.cols.kz`)** — a
compiler-owned check inside the `stored` transform: for each
`stored { s.f: v }` write it resolves the destination column's numeric
type via `storeMemberColumns`, parses the RHS text through
`expression_parser`, proves the RHS numeric class/rank
(identifiers bound to store columns — including the post-`SRewrite`
`__koru_store_<s>.<col>[<row>]` spellings — literals, binary/unary
ops), and refuses cross-class or rank-losing writes with a named
KORU161 diagnostic quoting column, destination type, and proven
source type. **Unproven defers** — unknown is not safe, and not a
refusal either. This is the first verdict of the prepared-witness
shape: the semantic fact (dest type × proven src type ×
conversion class) is decided once, in the shared transform, so every
emitter inherits the verdict instead of each silently re-deciding it
in a host typecheck. Verified host-agnostic: `koruc --lang=c` produces
the identical diagnostic and emits no `.c`.

Honest warts on this change, stated not absorbed: (1) the check
re-parses RHS *text* — the elaborated value arrives lowered
(`__koru_store_*` spellings), so the fact is reconstructed per site
rather than arriving as a typed payload; the witness-channel work
(`ast.Arg` carries `parsed_expression`/`source_value` already) is the
real seam. (2) Coverage is numeric columns only — same-type
mismatches elsewhere still fall to host backends.

**`scripts/regression_lib.sh`** — three harness changes, each an
agnostic fix rather than a bandaid:
1. C leg gate widened: `C_REFUSES` alone is a complete contract (the
   pinned refusal *is* the expected outcome) — no `MUST_RUN`/
   `expected.txt` required. Only 690_160 carries MUST_ERROR+C_REFUSES;
   zero of the 532 error-expected tests carry MUST_RUN, so no other
   test's behavior changed.
2. Refusal detection keys on "no `output_emitted.c` produced" plus the
   pinned text — measured fact: koruc exits 0 when the backend run
   refuses (the KORU diagnostic is the program's verdict, not a driver
   crash). A stale `output_emitted.c` from a prior run is `rm`'d first
   so it cannot mask a fresh refusal.
3. The three equivalence legs (js/cs/c) are now invoked before the
   early `return 0`s in the frontend-error block (5 pin-branch sites)
   and the backend-exec-error tail — previously any test whose expected
   outcome was *a refusal* exited before the legs ran, so a `*_REFUSES`
   marker on a MUST_ERROR test was dead text. This repairs the same
   latent hole for JS_REFUSES/CS_REFUSES, not just C. Verified by
   negative probe: a corrupted `C_REFUSES` flips 690_160 to
   `c-compile` FAIL; the real pin prints `✓ C refused cleanly`.

**Known env artifact:** `_write_c_target`/`TARGETS.json` needs `node`,
which resolves to a broken Windows npm shim under WSL — the write
silently no-ops (`2>/dev/null`), so the `refused` verdict does not
land in TARGETS.json on this host. Verdict path itself is unaffected.

**Unit/regression state:** `zig build test` Foundation PROVEN;
filtered slice (all prior C pins on the stored surface + 690_160):
zig lanes green, C legs green or refused-as-pinned; only env-gap reds
(`cs-compile` on missing dotnet, `js-runtime` on the node shim).

## Tranche: prepared-witness channel, rung 1 (session, cont.)

**What landed.** The narrowing wall's verdict now *survives* the transform
that computes it. `storedWriteNarrowing` (which returned `?[]const u8` —
the diagnostic or nothing, discarding the proof) is split into
`storedWriteCheck`, returning a `StoredWriteVerdict` record
`{site, dest, src, narrows}` plus `storedWriteWitnessMark`, which renders
the verdict as a `.marks` entry:

    @witness("stored-write-numeric","bodies.x","f32<-f64","lossless")

`stored|zig` mints one mark per write onto the **lowered** write
invocations — `__store_envwrite_*` (plural+singleton envelope paths) and
`__store_write_*` (single-write path) — i.e. onto the obligation site the
emitters actually see, not the `stored` surface call that dissolves.
`.marks` is compiler-internal, never parsed from surface syntax: a
witness is unauthorable by grammar, which is the property the
callsite-proofs draft (W1) recommends for the whole witness surface.

**Verdict vocabulary:** `lossless` | `deferred` | `non-numeric` |
`refused`. `deferred` is the new enumerable fact — an unproven write
previously vanished into the same silence as a proven one; now it leaves
a mark a checker can count. `refused` marks are minted but never survive
(the program dies at the refusal — the refusal itself is the receipt).

**Consumer rung.** `std/witness:enforce` runs in Phase 2.5 `comptime_main`
on the post-transform AST, so it sees the minted marks for free. Its
census now walks continuations recursively, parses `@witness(` marks, and
prints one stable line during backend execution:

    [witness] stored-write-numeric: lossless=1 deferred=1 non-numeric=0 refused=0

The `witness` *command* dispatches on `seed_ast` before the transform
pass — it cannot see marks and was left unchanged rather than printing a
zero-row lie. `comptime_main` also runs at Phase 2.3.5 (pre-transform
prime), so the enforce print is gated on `witnessSites() > 0`.

**Pinned:** `690_364_witness_marks_ride_lowered_stored_writes` — an
`enforce`-declared program with one proven-lossless write and one
unproven write; `expected_comptime.txt` pins the census line. 690_160
still refuses identically (KORU161, f64→f32). Control slice over the
`stored` surface: zig lanes green, only env-gap reds (dotnet/node
shims); no KORU161 anywhere unexpected.

**Frag:** `frag-a-verdict-not-minted-onto-the-lowered-site-evaporates` —
the belief this tranche proves: a computed verdict dies with the call
unless minted onto the node that survives the rewrite.

**Deferred to next rungs:** W1/W6 Lars rulings now have a concrete
instance to point at; a sidecar witness artifact for K3 (the `[witness]`
lines are already the greppable record); `enforce`-contract refusals on
nonzero `deferred` counts; witness minting for the other obligation
families the draft enumerates (mint/move/discharge edges).

## Tranche: witness rung 2 + K3 Role A/B for the numeric fragment

**Re-decidable marks.** Literal writes now mint the literal itself:
`@witness("stored-write-numeric","bodies.x","f32<-literal:0.1","rounds")`.
`literalExactIn` (store.cols.kz) decides exact representability with u128
integer arithmetic only — int columns by range after `/10^k`, float columns
by `N = M·5^k`, `M = odd·2^t`, fit of bit length and exponent window. New
verdict `rounds` (a decimal no value of the column holds exactly) — a
recorded fact, never a refusal; writeExprNumInfo and the KORU161 wall are
untouched. Unrecognized literal text (exponent, hex, `_`) or u128 overflow
stays `deferred`.

**Per-site records.** `enforce` prints one line per mark, AST walk order,
before the census:

    [witness] site stored-write-numeric bodies.x f32<-literal:0.1 rounds
    [witness] stored-write-numeric: lossless=3 deferred=0 rounds=1 non-numeric=0 refused=0

Mark parsing is strict (four quoted fields); a malformed mark is counted
and printed nowhere. 690_364 pins four writes (f64<-f32, literal 1.5,
literal 0.1, literal 16777217 into f64).

**K3 — `verify/k3/WitnessCheck.lean` (Lean 4.31.0, pinned in
tools/tools.json).** Role A: `typed_lossless_sound`, `int_literal_sound`,
`float_literal_sound` — a lossless verdict implies the value lands
unchanged under the integer-range / `m·2^e` value semantics. Role B: the
same file as `lean --run`, ruling on every `[witness] site` line. Float
exactness is decided by exhaustive exponent search over unbounded naturals,
a deliberately different derivation from the Zig formula. `golden.txt`
(18 hand-derived lines: boundary ints, 2^24 / 2^24+1, -0.375, 0, 3.0 vs 2.5)
must all MATCH; `forged.txt` (15 lines: wrong verdicts, narrowing claimed
lossless, unknown tokens, unknown kind) must all be rejected (N4).

**Gate: `scripts/k3_witness_gate.sh`** — Role A check, golden, real
corpus (default: 690_364's backend.err, so run that test first), forged.
Missing Lean is FAIL. Negative-probed: one corrupted golden verdict flips
the gate to FAIL; restored, PASS. Measured: real corpus 4/4 MATCH.

**Still open:** the gate is not yet wired into run_regression.sh (it costs
an external toolchain — an oracle budget, per §3.5); the first *obligation*
fragment (S5, custody kinds) is Lars's ruling; marks from the
auto-discharge family.

## Tranche: witness rung 3 — pass-witness-check, discharge witnesses, [strict]

**Pipeline.** `pass-witness-check` sits immediately after `pass-auto-discharge`
in `~analysis` (koru_std/compiler.kz) — the §3.5 `obligation-synthesis |>
witness-check` split. It is a no-op unless the program declared
`std/witness:enforce`; since Phase 3 strips comptime flows, `enforce|zig` now
only registers `emitter_helpers.witness_enforced = true` (build:variants
registry shape) and the pass owns all printing: site lines in walk order,
then per-kind census lines (`stored-write-numeric: …` byte-identical to
before; `auto-discharge: sole=N preferred=N`). 690_364 passes unchanged —
the numeric marks survive from transform to analysis.

**Discharge witnesses.** `selectWithWitness` (src/auto_discharge_inserter.zig)
wraps `selectDisposal` at all three selection sites and mints
`@witness("auto-discharge","<binding>","<state>-><disposer>","<rule>:<cands>")`
onto the inserted disposal invocation's `.marks`; rule is `sole` or
`preferred`, cands carry `!` for `[!]`. Fields containing a space, `"` (or
`,` in a candidate) mint nothing rather than a malformed mark. 330_138 pins a
preferred and a sole pick.

**[strict].** Mirrors the module-word convention (compiler.kz ~2541): under
`[strict]` + enforce, every `stored-write-numeric` mark verdicted `rounds` or
`deferred` is a KORU161 refusal at the write's flow:
`std/witness: [strict] requires every stored write to be proven lossless —
'bodies.x' (f32) is written from literal 0.1, which rounds in f32`. 690_365
pins the refusal, 690_366 the admitted case. KORU161 because no witness-family
code is reserved (scripts/registry_reserved.txt) and this is the store's
write-refusal class — a W3 code decision for Lars.

**K3.** The Lean file gained the `auto-discharge` kind: `pick` re-runs the
policy over the recorded candidates, `pick_sound` proves a pick is a
candidate and forced (only candidate, or only `[!]`). Golden +3, forged +7.
Real corpora: 330_138 2/2 MATCH, 690_365 1/1, 690_364 4/4, 690_366 2/2.
330_138 and 690_366 carry K3_WITNESS. Stated limit: the checker cannot see
whether the recorded candidate list is complete.

## Tranche: numeric check reaches the honest floor (commits 47500f627..a410df5e2)

**Column types for every store shape.** `storeColType` uses the
`storeFieldOrder` cascade (insert decl -> apply decl -> seed block) so
capacity-1 stores stop leaking writes past the wall; a lone literal operand
adopts its typed peer when exactly representable there (mirrors Zig peer
resolution). Harvest: non-numeric 225->7, lossless 72->309.

**Scope env.** `writeExprNumInfo` types bound names through
`emitter_helpers.scopeAtSite` (empty env -> deferred, never a refusal) and
`@as(T, _)` counts as the author's own coercion. deferred 95->74,
lossless 309->334.

**Row bindings + lifecycle payloads.** `| row r` binds the index, `! row e`
the record — same word, split by sigil; the record arm inherits the
terminal's `usize` payload on the decl, so `rowBindStoreAtSite` re-checks
arm kind over the site ancestry instead of trusting the stamped type.
`! inserted|removed { f }` destructure fields pun columns (user type text
there is refused — untyped is the only shape); `! updated { old, new }`
binds the written field's images under the decl's uniform-column
enforcement — `lifecyclePunAtSite` covers both. The lowered read
`(&__koru_store_S.f)[i]` is compiler-internal text (`&` has no unary form,
a grouped primary takes no postfix) and is normalized to `S.f[i]` before
the surface parser sees it. deferred 74->54, lossless 334->354.

**The floor is honest.** The remaining 54 deferreds are dominated by
`| row`/`[id]`/`! cleared` handle writes — `usize` sources into `i64`
columns. usize->i64 is not provably lossless at type level (values >= 2^63
reinterpret), so `deferred` is the correct verdict, and the Lean checker
independently agrees: 481/481 MATCH on the re-harvested corpus. Fixing
them means a host-width pin (usize==u64) — a semantics question for Lars,
not a decode gap. Small residual: builtin result typing (`@divTrunc`
etc.), `e.str`-class non-numeric columns.

Measured: corpus harvest 359 tests / 342 clean / 481 witness sites /
180 tests with >=1 witness; injection caused 0 of the 17 non-clean.
