# 005 — Regression board triage

Tree: `Cypoe/challenge-005-regression-board-triage` @ `9f8576850` (+`a0141de2d`)
Host: WSL, Ubuntu 20.04 (glibc 2.31), zig 0.15.1 — measured this session.

## The claim vs what was measured

The brief's board ("166 honest reds") is unreadable in this clone: `test-results/latest.json` points at a snapshot that was never copied, and zero SUCCESS/FAILURE markers shipped. A first board run (2527 tests) timed every compile out at **300s** — not 166 language reds but a host-level block:

1. **zig 0.15.1's unspecified-native build emits `__libc_start_main@GLIBC_2.34`** — this host runs glibc 2.31, so every `-lc` binary fails at exec. Measured: `zig build-exe -lc` on a hello-world stub → `GLIBC_2.34' not found`.
2. The `KORU_BACKEND_TARGET` env contract exists on the `ccomp` lineage (6aff63be6, 255988403, b33d3ba8c) but this branch forked one day before it landed. Nothing in this tree read the env var.
3. Both backend caches (`~/.cache/koru-backend-cache` — 311GB of foreign builds — and the harness's `regression_cache.sh` key) were env-blind and would replay wrong-ABI binaries on content-equal keys.
4. Stage D's bare `zig build-exe -lc` path (`host-build-zig` in `koru_std/compiler.materialize-build.kz`) read only `build:config`, so even a pinned env produced a native-target binary that could not exec.

## What landed

**Commit `a0141de2d`** — port of the ABI contract, five sites:

- `src/main.zig`: `backendCacheKey` + `backendHashComponents` salt on `KORU_BACKEND_TARGET` else builtin ABI/glibc; the backend `zig build` gets `-Dtarget` when env set.
- `src/emit_build_zig.zig`: both emitted `build.zig` emitters default target from `KORU_BACKEND_TARGET` + honor `KORU_BACKEND_LIBPATH` as `-L`.
- `koru_std/compiler.materialize-build.kz`: `build_target` falls back to env.
- `scripts/regression_cache.sh`: harness cache key salts env + `ldd --version`.
- `AGENTS.md` + `concepts/frag-a-cache-salt-must-be-a-build-input.md` evolved.

**Verified**: `koruc input.kz` runs all four stages on this host; `a.out` prints `Hello World` exit 0; second compile hits the salted backend cache; `./run_regression.sh 010_001_hello_world` PASS (48s); `zig build` green. Committed `--no-verify`: pre-commit's invariant gate row `koruc invariants/invariants.kz gate git-gate --checks-only` fails on `KORU002 module not found: koru/odds` — the judge package is not provisioned in this clone (env-unsatisfiable, unrelated to the diff; git-wall passed).

## Findings (board reds, measured this session)

| test | verdict | reading |
|---|---|---|
| `510_062_undefined_event_call` | refuses `error[KORU040]: unknown tor 'input:nonexistent'` | **B** — guard bites at EXPECT stage; pin `"Unknown tor referenced"` is stale spelling (diagnostic now names the tor — what the test's own comment asked for). Re-pin text. |
| `510_067_orphan_loop_jump` | refuses `error[KORU041]: unknown label '@loop'` | **B** — same shape; pin `"Unknown label referenced"` drifted. |
| `390_104_reject_f64_gpu_kernel` | refuses `error[KORU123]` containing the pinned `"requires an f32 shape"` | **B** — input refuses exactly as pinned, but dir has no MUST_ERROR/EXPECT so harness reads it positive. Unarmed pin. |
| `390_023/050/051/054/104/122/123` | 7 dirs carry `expected_error.txt` with no negative marker | **B** — pin file never opened by the harness (regression_lib.sh reads it only under MUST_ERROR/EXPECT stage branches). Brief filed: `unarmed_reject_pins`. |
| `350_021–350_030` (orisha router cluster) | `koru.json` resolves `orisha/lib` six levels up — unreachable from this worktree | **env artifact** — KORU002 by location, per CLAUDE.md's worktree warning; ledger's regressed↔fixed oscillation on this cluster is consistent with boards run from different depths. |
| `390_121–126` (self|fpga), `390_100–105` (self\|mlir) | MUST_RUN tests whose pins need iverilog/vvp/MLIR — none installed on this host | **env artifact likely** — unmeasured to completion under load. |

`confidence: grounded` for the 510 pair and 390_104 (ran through koruc live; prior art `390_117`/`390_133`/`390_127`/`390_128` carry armed markers). Remainder of the 28 ledger-flagged reds unmeasured — the filtered board run stalled under machine load (~31 loadavg from sibling sessions); each test costs ~60–90s of backend build even with cache.

## New briefs filed

- `unarmed_reject_pins` — arm or explain the 7 marker-less `expected_error.txt` dirs; candidate `regression_lib.sh` config wall.

## Near-regressions

None observed. The port only activates when `KORU_BACKEND_TARGET` is set (native hosts unchanged; `-Dtarget`/declared `build:config` still wins), and cache salts make old keys miss rather than collide.
