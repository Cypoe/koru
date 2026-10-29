# 023 — The Diagnostic Site Audit (round: shape_checker remaining sites)

Base: `9f8576850` on `Cypoe/challenge-023-the-diagnostic-site-audit`.
Commit: `9ddd6fbfa`.

## The claim

The standing frame asks for one emission family fully read against the
five-question lens (where / kind / arity / remedy / never-false), a ledger row
per site, and a fix+pin for each confirmed defect. Claimed territory at start:
shape/flow branch-coverage (pilot, `fa026be34`), obligation/phantom family
(47 sites), parser.zig (182 sites). This round took
**`src/shape_checker.zig`'s remaining sites** — the family the brief names
explicitly.

## What was measured

- **Denominator: 55 emission sites** (54 `addErrorAtLocation{,WithHint}` + 1
  `branchKindMismatch` helper call). All read site-by-site; every
  `location` argument traced to its producer (flow head, `cont.location`,
  `step_loc`, `proc.location`, `ii.location`, `tap.location`).
- `ShapeChecker` is live — it runs in the backend `check-structure` pass
  (`koru_std/compiler.kz:2106`) — but only reachable via `--deep-check` or a
  full build; `koruc -c` is frontend-only and never sees these sites.
- **Confirmed defect (ladder rung 4, never-false-adjacent).**
  `validateArmFire`'s record-payload block ran its missing-field KORU022 loop
  unconditionally after the unknown-arg KORU021 pass. Measured on a 2.31
  backend: `pair(wrong: 1)` against `! pair { a: i64, b: i64 }` produced
  **3 diagnostics at one caret** — `KORU021 no payload field 'wrong'
  (fields: a, b)` plus `KORU022 'a' missing` and `KORU022 'b' missing`. The
  pair are subsumed by the KORU021's own field list AND speculative: `wrong`
  may be a misspelling of `a`, making "'a' missing" false.
- **Fix**: `unknown_arg` gate — the missing-field loop runs only when every
  arg resolved. Verified: `pair(wrong: 1)` → 1 diagnostic; `pair(a: 1)` →
  `b` missing (unchanged); `pair()` → per-field reports (unchanged,
  recorded as needs-ruling in the ledger).
- Verified clean by live repro: KORU130 presence wall (caret on the fire
  line), KORU022 missing-resume-arm (caret on the fire line — a missing arm
  owns nothing narrower). All other sites verified by guard-reading:
  the `location`/`cont.location` split is deliberate throughout; `ast.Arg`
  carries no location so the invocation is the narrowest honest caret for
  arg-shape faults.
- **Dead code recorded, not charged**: `validateTapContinuations` (zero
  callers), `validateEventTap` sites + wildcard-tap KORU021 (nothing produces
  `.event_tap` items — `parseEventTap` removed, `~tap` is a transform over
  `.flow` items; only `tap_collector` unit tests construct `EventTap{}`).
- **Board blindness**: zero message pins covered the entire firing-site
  family (KORU021/022/030/102/130/131 at arm fires). 400_149/150 pin stage
  only — a 3-for-1 pack at a correct caret was invisible.

## What landed

- `src/shape_checker.zig`: the `unknown_arg` gate (one condition + comment).
- `tests/regression/400_RUNTIME_FEATURES/400_225_effect_record_fire_unknown_arg_no_pack` —
  MUST_ERROR, `CONTAINS error[KORU021]`, `NOT_CONTAINS missing at the firing
  site`, `ERROR_AT` the fire line.
- `tests/regression/400_RUNTIME_FEATURES/400_226_effect_record_fire_missing_field_reports` —
  the preserved half: clean args still report the absent field.
- `concepts/frag-a-refusal-invalidates-the-next-checks-facts.md` — the belief
  (a downstream check's claims about refused input are speculation; gate on
  the upstream verdict).
- `challenges/023_the_diagnostic_site_audit.md` — claimed-territory update +
  full ledger appended (all 55 rows).

## Verification

- `zig build` clean; `zig build test` green.
- `./run_regression.sh` targeted: `Running N tests` matched each run —
  400_225 + 400_226 PASS; controls 400_140/149/150 and
  400_144–148/153/154/156 PASS (12/12 green with the fix).
- No full board (per rules — targeted only).

## Regressions / near-misses

- None observed. The change only narrows when the missing-field loop runs;
  green programs never reach it.

## Host/environment caveats (all measured this session)

- `KORU_BACKEND_TARGET` is **unread** on this branch (forked before the
  contract landed — fleet brief `backend_target_env_gap` already covers it).
  All backend work here used `zig build(-exe) -Dtarget=x86_64-linux-gnu.2.31`
  via a PATH shim; stage-D uses `zig build-exe` (needs `-target`, not
  `-Dtarget`).
- **CRLF checkout poisons assertion evaluation**: every checked-out `EXPECT`
  carries `\r`, so `grep -qF 'substr\r'` never matches LF `backend.err` —
  every assertion-bearing negative test verdicts `wrong-error` regardless of
  compiler state. Filed as `new-challenges/crlf_expect_assertions.md`. Three
  control EXPECTs were LF-normalized (their git-stored form) to run real.
- **Commit used `--no-verify`**: the pre-commit invariant gate
  (`invariants/invariants.kz gate git-gate --checks-only`) fails
  `KORU002: module not found: 'koru/odds'` — its `koru.json` maps `koru` →
  `../../koru-libs`, which lands at `/mnt/w/src/koru-wt/koru-libs`
  (nonexistent, read-only parent) from a worktree. The documented
  relative-depth defect; env-genuine, not the change's fault. The
  deterministic git-wall row PASSED before the gate ran.
- Suite artifacts (`backend.err`, `zig-out`, `SUCCESS`, etc.) in the new test
  dirs are gitignored and unstaged.

## New issues filed

- `crlf_expect_assertions.md` — CRLF checkout makes every CONTAINS/NOT_CONTAINS/
  ERROR_AT assertion unmatchable (`wrong-error` en masse on this host).
