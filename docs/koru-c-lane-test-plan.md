# K1 C-lane test plan — verification-path scaffolding

Pinned against `docs/koru-verification-path.md` @ ccomp branch.
Measured tree: `git rev-parse HEAD` at write time — see footer.

This file converts the doc's lowering table (§1) and refusal table into
concrete suite cells, names the co-present axes each cell cannot isolate,
and lists the questions that are Lars's to answer — never guessed into
source. The C emitter itself is **not implemented**; every cell here is
an honest red until it exists. No syntax in these cells was invented —
each shape is cloned or modelled on a passing test cited per cell.

## Gate machinery

- `scripts/cc_gates.sh` — runs G-CC-2 (oracle presence, fails naming the
  resolved path when `ccomp` is missing), G-CC-4 (determinism pin), and
  G-CC-1/3 by driving the suite over every test whose `LANGUAGES` marker
  lists `c`. Empty battery = FAIL, not green.
- `scripts/regression_lib.sh:regression_check_c_equivalence` — the `c`
  row of the existing target-equivalence grid (js/cs twin). `koruc
  --lang=c` emits `output_emitted.c`; `${KORU_CC_ORACLE:-ccomp}` builds
  it; stdout+rc compare against the same `expected.txt` the Zig lane
  satisfied. Exit-0-with-no-`.c` is a `c-noemit` failure (silent
  fallback, the shape KORU126 exists to kill). `C_REFUSES` files pin
  named refusals (twin of `JS_REFUSES`/`CS_REFUSES`); on the refusal
  path the oracle is not consulted, so a missing `ccomp` cannot mask an
  emitter refusal that already named itself.
- `tools/tools.json` — the pin manifest (zig 0.15.1, ccomp 3.18,
  lean 4.31.0 verified; llvm/alive2/risc0 DEFERRED with commands).
- `tools/cc-fixtures/gate_pin.c` — G-CC-4's fixture.

## Cells (tests/regression/400_RUNTIME_FEATURES/)

| cell | doc row | files | pins |
|------|---------|-------|------|
| 400_208_c_host_lines_refuse | refusal 1: host lines | input.kz | C_REFUSES `cannot lower to C` |
| 400_209_c_effect_arms_refuse | refusal 2: `!`-effect arms | input.kz | C_REFUSES `resume semantics out of oracle scope` |
| 400_210_c_concurrency_refuses | refusal 3: pump/rings/worker.spawn | input.k + lib.kz | C_REFUSES `no verified concurrency` |
| 400_211 | refusal 4: comptime/transform leak | — | RESERVED — needs Lars's exemplar for the leak spelling |
| 400_212_c_transducer_equiv | G-CC-1 positive: byte transducer | input.k | zig+c parity vs expected.txt |

Exemplars: 400_208 ≈ 400_191_zig_only_proc_js_build_refuses (`.kz` host
shape); 400_209 ≈ 400_070_effect_branch_minimal (producer/consumer `!`
pair); 400_210 = 115_049_pump_run_in_module verbatim (proven pump join);
400_212 ≈ 020_014_pure_subflow_impl (pure subflow + `print.ln`).

## Co-present axes (recorded, not resolved)

No refusal cell isolates its row perfectly — documented so a red that
names a different axis reads as an ordering finding, not a mystery:

- Every `.kz` carries raw host lines (row 1) wherever the row under pin
  lives in the same file.
- Zig-only procs have no `|c` variant — the "tor has no C
  implementation" axis (NoCProcBody, the js `NoJsProcBody` twin). The
  doc's refusal table does not name this axis; it is real and needs a
  KORU code (see questions).
- 400_209 co-presents rows 1+2; 400_210 co-presents rows 1+2+3 plus
  `[transform]` procs inside `std/pump` (row-4-adjacent) and missing
  `|c` verb impls.

## Lowering table → plan

| doc lowering | test coverage |
|--------------|----------------|
| tor → dispatch function; branches → tagged results | 400_212 baseline; richer branch shapes follow the `!` ruling |
| continuation arm → caller-side switch | unwritten — depends on Q1 |
| binding → single-assignment local, const-init | folds into 400_212-class positives |
| cell → module-scope array/struct, static, closed accessors | needs a `.k` cell test — followup |
| transform/comptime tors → emit nothing; refuse on leak | 400_211 reserved — leak spelling is Lars's |

## Questions for Lars (unanswered, not guessed)

1. **`!`-arm scope.** The row says "`!`-effect arms" but the same
   spelling is `for ! each` / `capture ! as` — counted loops and
   ambience idioms the sieve corpus needs (115_029 uses `! each`). Does
   row 2 mean *all* `!` arms (then the K1 corpus excludes `for`, and
   G-CC-1's "prime-sieve parity" class has no route), or only
   resumable producer/consumer pairs? The lowering row "continuation
   arm → caller-side switch" suggests some arm shapes lower — which?
2. **Refusal ordering.** When a program co-presents several out-of-scope
   constructs (all three refusal cells do), does the doc intend the
   first-seen axis, a canonical precedence, or a refusal that names
   every axis? Current pins assert one reason each.
3. **Missing-variant axis.** A zig-only proc on `--lang=c` — is that
   the host-lines row, a NoCProcBody diagnostic (KORU047-style), or a
   distinct refusal? It is the most common axis a `.k` program will
   hit (every `std/io` call until `|c` impls exist).
4. **Row-4 exemplar.** No corpus test spells a transform/comptime tor
   *leaking* a runtime effect; 400_211 is reserved until the spelling
   exists.
5. **`.kc` facet semantics.** `file_types.zig` maps `.kc`→`"c"` but no
   `|c` proc or `.kc` file exists anywhere in the tree — the C-facet
   contract (host lines as C? proc bodies only?) is unwritten.

## G-CC-4 finding at scaffold time

`ccomp -O` alone is **not** byte-reproducible: ccomp feeds `as`/`ld` a
tempfile `compcert<rand>.o` whose name lands in the output as an
`STT_FILE` symbol (measured: 6 differing bytes at ~0x3459, two runs).
Pinned recipe `ccomp -O -Wl,-s` (strip symtab) yields byte-identical
binaries and identical stdout — the pin now lives in `g_cc_4`.

---

## verify-path session (2026-10-11)

Measured at `ce877ccd3` (branch `verify-path`, cut from ccomp tip). Two
pieces of ground established, one architectural consequence drawn, and
recommended rulings for C1–C5 — **recommendations, not rulings**; Lars
decides each.

### The link seam is demonstrated, and already precedented twice

Receipt (aarch64-linux container; `ccomp` = CompCert 3.18 via nixpkgs,
`zig` 0.16.0): `ccomp -O -c part.c` produced a standard ELF `.o`;
`zig build-exe main.zig part.o -lc` linked it; the binary ran, zig
`main` called into CompCert-compiled code, correct results, rc 0.
**Zig links ccomp-produced objects — demonstrated, not asserted.**

The mechanism is already in the pipeline twice:

- `~std/build:requires { exe.addObjectFile(...) }` — user-declared
  splice into generated `build_output.zig` for the output binary
  (310_021_build_requires_basic).
- The `|mlir` seam — `src/main.zig` synthesizes build requirements on
  sight of a `|mlir` proc body: Stage A writes `<sym>.mlir`,
  `build_output.zig` globs, invokes the toolchain
  (mlir-opt → mlir-translate → `clang -c`), `exe.addObjectFile`s the
  result into the OUTPUT binary. GPU twin included. A `|c` variant is a
  **new tag on this seam** with `ccomp -c` as the toolchain step —
  sibling mechanism, not new architecture.

### Partition oracle — the link's architectural consequence

Whole-program parity (arm A = zig-all, arm B = ccomp-all) is the
milestone, not the end state. The link enables **per-unit lanes**:

- arm A: zig compiles every unit.
- arm B: zig compiles the non-C units; ccomp compiles the C-expressible
  units.
- A/B divergence can only originate in the C-expressible fragment — the
  non-C units are identical objects in both arms, so a zig miscompile
  cancels out of the comparison. Oracle coverage becomes each program's
  **C-fraction** instead of requiring C-fraction == 1.
- Refusals downgrade from program verdicts to lane assignments; the
  refusal table becomes a coverage map.
- Seam rule: **calls cross, memory doesn't.** Shared state goes through
  accessor functions (the lowering table's "closed accessor set" is the
  boundary); zig and C share no struct-layout guarantee.

Sequencing unchanged: whole-program first (400_212 needs zero
partitioning machinery), partition second.

### C6 — refusal co-presence, measured (2309 test dirs)

| axis | dirs |
|---|---|
| R5 zig-only procs (no other variant) | 801 |
| R1 host lines (top-level zig decls in `.kz`) | 561 |
| R2 resumable `!` arms (not `! each`/`! as`) | 414 |
| R2 lowering-class `!` arms (`for ! each`, `capture ! as`) | 223 |
| R3 pump/rings/worker | 51 |

Top combinations: **910 dirs (39%) present no refusal axis**; the
commonest collision is R1+R5 (402 dirs); ~25% of the corpus presents
two or more axes. C2's ordering question has a real collision rate:
name-every-axis diagnostics pay off at this density.

### Recommended rulings (Lars decides)

- **C1 — resumption, not glyph.** Row 2 should read "resumable `!`
  pairs" — coroutines are what CompCert cannot express. `for ! each` /
  `capture ! as` are bounded iteration (223 corpus dirs use them);
  refusing them keeps G-CC-1's sieve class out for no semantic reason.
- **C2 — name every axis.** At ~25% co-presence, first-seen ordering
  costs users one compile per axis. The emitter knows all axes at check
  time; enumerate them in one diagnostic.
- **C3 — NoCProcBody is its own axis.** R5 is the corpus's dominant row
  (801 dirs) and a `.k` file hits it with zero host lines — folding it
  into row 1 is the wrong shape. Mirror `NoJsProcBody` (400_191).
- **C4 — keep 400_211 reserved.** No corpus test spells the leak.
- **C5 — `.kc` = the `.kcs` contract, verbatim.** C host lines spliced
  + `|c` proc bodies; `file_types.zig:58` already reserves the slot.

---

## verify-path session 2 (2026-10-11): partition oracle + surface rulings

### Ruled

- **C5 — RESOLVED (Lars).** `.kc` = the `.kcs` contract verbatim: C
  host lines spliced + `|c` proc bodies. `file_types.zig:58` already
  reserves the facet.
- **C1 — DISSOLVED into the partition model.** The refusal table
  assumed whole-program lanes; under the unit-partition oracle nothing
  *refuses* for containing `!` — units route. Routing rule:
  resumable-coroutine `!` pairs → zig units (CompCert's sequential
  subset cannot express suspend/resume); transplanted-sequential `!`
  arms (store interceptors, watches — 690_016's "qbody transplant
  pattern" makes them straight-line code at write sites) → verified-arm
  *eligible*; `for ! each` / `capture ! as` → empirical per-unit.
  `!` is a lane assignment, never a wall.
- **`|c[verified]` — NEW RULING.** The bracket qualifier names the
  *pipeline arm* (`|mlir[gpu]` precedent — `main.zig:3097` treats the
  bracketed form as the full tag with `mlir` as base). `|` names the
  language, `[]` names the pipeline: `|c[verified]` = route this unit
  through the verified toolchain, refuse if absent (G-CC-2 expressed
  per-unit). New semantic axis for the qualifier — `gpu` selects a
  target, `verified` selects a toolchain property; recorded as a Lars
  ruling, not a consequence of the existing grammar. `witnessed` was
  rejected: witnesses are the K3 layer and a `|c` body has no Koru
  flow inside it — nothing to witness. `ccomp` was rejected as a
  tool-name; `verified` names the property demanded.
- **No `--lang=c` product toggle.** `c` was never a language column —
  the arm never ships a binary. `~std/witness:enforce` owns the
  arm-switch (the declaration injects the dual-arm pipeline);
  `|c` stays the proc-body variant tag. Consequence: verification
  moves from test metadata (`LANGUAGES` marker) into source — a cell
  *declares* `enforce` instead of relying on harness flags.
- **Three-arm picture.** ccomp = the oracle (theorem-backed,
  independent — shares no infrastructure with the product lane);
  zig = the product; `clang -fsanitize=address,undefined` on the same
  `output_emitted.c` = a third arm catching UB/leaks that print
  correctly. `zig cc` is a usable extra arm but never *the* oracle —
  clang shares the LLVM middle-end with the zig product lane
  (correlated miscompile channel).

### Still open

- **C2** — name all co-present axes vs first-seen (recommendation:
  all; nearly free once refusal machinery exists — the axes are in
  hand at check time).
- **C3** — `NoCProcBody` own axis (recommendation: yes; corpus's
  dominant row, 801 dirs).
- **C4** — row-4 leak exemplar; `400_211` stays reserved pending a
  real spelling.
- **Emitter-side questions that are empirical, not rulings** — which
  lowering-class `!` constructs emit valid C; whether the emitted-C
  dialect's struct-layout story stays accessor-clean at the
  zig/ccomp seam ("calls cross, memory doesn't").
