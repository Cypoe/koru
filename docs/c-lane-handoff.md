# c-lane — return handoff (2026-10-12)

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
