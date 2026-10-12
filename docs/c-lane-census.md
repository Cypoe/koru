# C-lane refusal census — measured distribution

Tree: `ccomp` @ `d237bf4ff` (post HostTarget-arm fix). Method: every dir under
`tests/regression/` with an `input.k`/`input.kz` got `koruc <entry> --lang=c
[COMPILER_FLAGS]` and one of four verdicts — EMITTED (nonempty
`output_emitted.c`), REFUSED (KORU047 axes or KORU121 no-`|c`-template),
FRONTEND (earlier diagnostic), TIMEOUT. Per-test `.zig-cache` and artifacts were
deleted after probing. 2309 rows (`~/c-census/census2.tsv`, probe:
`~/c-census/probe2.sh`); ~13 rows are dup-dir artifacts of the sweep list.

## Verdicts

| verdict | n | share |
|---|---|---|
| REFUSED (named axes) | 1422 | 62% |
| FRONTEND (pre-C diagnostic) | 741 | 32% |
| EMITTED | 146 | 6% |

The refusal table fires on nearly two-thirds of the corpus — the instrument is
live; most programs that reach the emitter get a named reason, not silence.

## Refusal axes (co-present; counts are mentions)

| axis | n | reading |
|---|---|---|
| `no-c-template` (KORU121) | 330 | a `[template]` tor lacks a `\|c` proc — see construct ranking |
| `raw host lines` | 326 | `const std = @import(...)`-style zig lines — by-design refusal, will not shrink |
| `no C type in first fragment` | 219 | type-mapping gap (slices, tagged unions, wider ints) |
| `named branches` | 187 | tagged-result shapes — parked per deflate ruling |
| `effect arms` | 163 | `!` — mixes genuine resumables with `~for`-governed transplants; needs sub-classification |
| `no \|c proc body` | 152 | proc bodies without `|c` variant — see ranking |
| `pump / rings / worker.spawn` | 35 | concurrency — presence-scoped, stays refused |
| `subflow impls` | 2 | multi-impl dispatch — out of fragment |

## `no-c-template` constructs (which tors need `|c` template procs)

`~for` **155** · `~if` **122** · `~const` 21 · `~cond` 8 · `~from` 5 ·
misc probes ~15. `~for` + `~if` alone carry 84% of this wall — and are exactly
what a prime sieve needs.

## `NoCProcBody` ranking (which procs need `|c` bodies)

`input:main` 19 · `input:seed` 10 · `__store_insert_*` ~30 total
(compiler-synthesized store-literal inserts — the transform needs to emit
`|c` variants, not users) · misc user procs.

## FRONTEND bucket — mostly not C-lane signal

`rc1` 266 (parse-level failures, heavy in negative tests) · `KORU030` 98
(shape mismatch) · `KORU161` 78 (store malformed decl — negative tests) ·
`KORU021` 28 · `KORU010` 28 · `KORU173` 21 · `KORU022` 17. These dirs die
upstream of emission; the corpus's negative tests correctly refuse.

## Oracle pass — 146 EMITTED dirs under `ccomp -O -fstruct-passing -Wl,-s`

| outcome | n |
|---|---|
| compiles, runs, stdout byte-matches `expected.txt` | **36** |
| compiles, runs clean, no `expected.txt` to compare | 55 |
| compiles, binary fails at runtime | **45** |
| ccomp rejects emitted C | 10 |

Two measured bug classes, both real:

- **Domain types not emitted** (10 dirs, mostly `665_PROTO`, phantom tests):
  emitted C references e.g. `const Health` where `Health` was never declared —
  record/domain types declared in non-input modules don't reach `output_emitted.c`.
- **Int→pointer type confusion → segfault** (at least `020_021`): emitted call
  passes `long long` where `char const *` is expected — an arrow-return value
  lowered into a string context. The `run-failed` bucket is crashes, not
  benign exit codes. 1 additional dir has a stdout mismatch vs `expected.txt`.

## Measured next moves (K1 acceptance = transducer + prime-sieve parity)

1. `~for|c` + `~if|c` template bodies — 277 dirs of template wall, and the
   sieve's two control-flow needs.
2. `~const|c` (21) — cheap, same class.
3. `__store_insert_*` C variants — the sieve's store/grid path; transform-side
   work, not user-facing.
4. Type-mapping widening (219 dirs) — the sieve's `i32`/numeric story.
5. Emit referenced domain/record types into C — fixes the 10-dir ccomp class.
6. Sub-classify `effect arms`: `~for`-governed `!` arms are transplant sites
   (eligible once `~for|c` exists); runtime-event arms stay refused.
7. Fix the int→pointer lowering — real correctness bug, needs a repro pinned.
8. `named branches` (187) stays parked; `raw host lines` (326) is the refusal
   boundary working, not a gap.

Note for triage: EMITTED rows counted programs where `output_emitted.c` is
nonempty — a handful of those dirs are tests that pin other behavior; the 36
byte-matches are the honest G-CC-1 pool.

## Delta — `~for|c` / `~if|c` / `~const|c` landed (session 4, ccomp)

The first widening tranche is in and measured. Same probe, same corpus —
the 277 dirs that refused `no-c-template` on `~for`/`~if` were re-probed
after landing `for|c`, `if|c`, `const|c`, the emitter's marker resolver,
and the transplant-vs-resumable census split:

| outcome | n |
|---|---|
| `no-c-template` refusal on `~for`/`~if` remaining | **0** |
| newly EMITTED | 13 |
| still REFUSED — other co-present axes | 193 |
| FRONTEND (legit upstream diagnostics) | 71 |

The `for`/`if` template wall is spent. What the remaining 193 name is
the next measured mass, unchanged in kind: raw host lines 41, effect
arms 35 (genuine resumables — see split below), no-C-type 31, named
branches 27, `NoCProcBody` 23 (`__grid_write_*`/`__store_insert_*` —
transform-synthesized procs stamping `.target = "zig"` under `--lang=c`).

### What landed

- `koru_std/control.targets.kz` — `if|c` (`c_lower` on the condition;
  `__koru_continue_N` hand-offs), `for|c` (counted `0..N` → C `for`,
  never `while`; `! each` binds via `__koru_inline_scoped_N`; non-range
  iterables render `__koru_c_refuse_non_range_for`, a named refusal).
- `koru_std/declarations.targets.kz` — `const|c`: `static const` decls,
  hoisted to file scope by the new `//@koru:file_scope` flag (C gives
  each flow its own fn — a decl inside one is invisible to siblings).
- `src/c_emitter.zig` — `emitInlineBodyResolvingContinuations` (port of
  the js emitter's marker resolver): `__koru_continue[_bare_]_N`,
  `__koru_inline_[scoped_]_N(arg)`, `__koru_c_refuse_*` → named
  KORU047; other `__koru_*` tokens are prelude runtime names and pass
  as host text. Drain semantics = js's `emitUnconsumedContinuations`.
- **Transplant-vs-resumable split** (the census's open item #6):
  `axisRefusalSite` now carries `governed` — a `!` arm whose parent
  invocation or flow carries `inline_body` is template vocabulary
  (`for ! each`), not a resumable pair. Genuine `!` arms on events
  (400_209's `~ping ! pong`) still refuse by name.
- `koru_std/io.cprec.kz` — `{{ x:d }}`/`{{ x:f }}` route through
  `__koru_stdout_write_i64`/`_f64` instead of the `const char *` write
  — the spec is the author's own type declaration. This kills the
  int→pointer segfault class *inside interpolated prints* (the
  `020_021` arrow-return funnel is a different path, still open).
- `build.zig` — `template_processor_tests` gained the `codegen_utils`
  dep the file already imported (pre-existing module gap).

### New equivalence cells

`400_211` counted for · `400_213` if/else · `400_214` if inside `! each`
(the sieve skeleton) · `400_215` const file-scope — all `zig c`,
byte-identical under ccomp. The four refusal pins (`400_208`/`209`/`210`,
plus `400_212` transducer) still hold.

### Prime sieve status

`2105_prime_sieve --lang=c` now clears `for`/`if` and dies on the NEXT
measured wall: `NoCProcBody` — `__grid_write_L32_1056` (`std/grid:stored`
synthesizes its write procs with `.target = "zig"` unconditionally).
The sieve needs the store/grid synthesis tranche: teach `grid.stored`,
`store.new`/`store.cols`, `sweep`, and `grid.new` to mint `|c` variants
of their synthesized procs and bodies.
