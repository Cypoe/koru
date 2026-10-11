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
