# verify-path — review handoff (2026-10-11)

Branch off `ccomp`'s tip, 7 commits of session work on top. This note
is the map; the detail lives in the appended `verify-path session`
sections of `koru-callsite-proofs-draft.md` and
`koru-c-lane-test-plan.md` — your questions are verbatim, our answers
sit next to them marked Ruled / Still open / Parked. Second pair of
eyes wanted on the *deltas*, not the plan itself — K1–K4 and N1 stand.

## Demonstrated, not asserted

- `ccomp -O -c part.c` → `zig build-exe main.zig part.o -lc` links and
  runs; zig calls into CompCert-compiled code, rc 0 (CompCert 3.18,
  zig 0.16.0, aarch64-linux container).
- `std/witness` scaffold is live: `~std/witness:enforce { }` runs at
  comptime and returns `.enforced` through the declaration's own arm;
  `koruc prog.k witness` prints an obligation + routing census. ~150
  lines of `.kz`, zero compiler changes — the surface rides
  `command.declare` + `[comptime]` transforms + `ast_find` folds.

## Deltas from the ccomp plan (and why)

- **No `--lang=c` product toggle** — `c` is a verification arm that
  never ships; `enforce` in source owns the arm-switch. (`--lang=c`
  is fine as internal plumbing; the ruling only bars it as a shipping
  column.)
- **`enforce` = "verify this program"** — a `[comptime]` declaration
  in the `std/build:variants` family (310_051). Verification becomes
  a property of the program, not of the invocation. Arm-shape
  agnostic: it means the same thing whether the arm is whole-program
  or per-unit.
- **Module-owned commands** — `std/witness` ships `[comptime|command]`
  tors (the `explain`/`gate` mechanism) as its driver surface, plus an
  `[explainer]` tor participating in the shared catalog. Explain
  participates; it does not drive.
- **The refusal table is the coverage instrument** — under
  whole-program lanes, out-of-fragment programs refuse naming *every*
  axis (C2 recommendation); the diagnostics measure what the wall
  costs rather than hiding it.

## Parked, not repudiated

- **Per-unit partition + `|c[verified]`** — coverage granularity at
  the price of new language surface for toolchain QA. Whole-program
  is the degenerate case and the lowering carries over; it returns
  only if measured refusal rates prove the wall costs too much.

## Correction to the record

- `!` is a *leading* arm marker (`! discharge item |> …`, 690_097),
  not a `| !` branch label — and its families split differently for
  lowering: store interceptors/watches transplant into write paths at
  comptime (690_016) → sequential → eligible; only resumable pairs
  (coroutines) cannot lower. C1 dissolved into that eligibility split.

## Rulings made / still open

- **Made (Lars):** W1 (.marks + `std/witness` vocabulary home), W7
  (absorb — the injected pass IS the checker), C5 (`.kc` = `.kcs`
  verbatim), `enforce` shape, flat enforcement level, the
  commands-vs-explain split.
- **Open:** W2-rendering (deferred to implementation), W3, W4 (the
  `witness` command makes it empirical per-program), C2, C3, C4
  (leak exemplar — needs invention), `enforce` body/branches spelling.
  All recorded inline under "Still open" in each doc.

## Where eyes would help most

- **`enforce`-in-source vs a harness flag** — the biggest divergence
  from K1's original shape; tell us if it reads wrong to you.
- **The three-arm picture** — ccomp oracle / zig product /
  clang-sanitizer arm on the same `output_emitted.c`; sanity-check
  the shared-LLVM correlation claim (`zig cc` is clang — same
  middle-end family as the zig lane, so never the oracle).
- **Absorb over wrap** — `phantom_semantic_checker` demotes to
  obligation-set producer and the new pass owns the verdict. If that
  is wrong for reasons we have not seen, now is the cheap moment.
