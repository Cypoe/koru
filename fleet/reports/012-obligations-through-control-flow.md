# 012 — Obligations Through Control Flow: round report

Tree measured: `0517d11e1` on `Cypoe/challenge-012-obligations-through-control-flow`
(built on `9125d583b` = `9f8576850` + the KORU_BACKEND_TARGET env commit,
cherry-picked-by-ff from the 011 worktree — required for any backend to exec
on this glibc-2.31 host).

## Headline

The brief's "34 reds / largest red mass" claim is **stale**. Measured this
session on the 31-test in-scope list (plus 4 controls): **28 pass, 0 compiler
failures, 3 parked TODOs** after one landed pin fix. The cluster map is
nearly empty — the bends mostly hold.

## Environment blocker found and resolved (precondition, not the yield)

- Every test initially failed `backend-exec`: zig 0.15.1 native build emits
  `GLIBC_2.34` refs; host is 2.31. Measured with a hello-world probe.
- The shared backend cache (`$TMPDIR/koru-regression-cache/koru-backend-cache`)
  was also serving foreign-glibc binaries — its key had no target salt.
- Fix already existed as sibling commit `9125d583b` (emitted build.zig honors
  `KORU_BACKEND_TARGET`, cache keys salted). Fast-forwarded the branch onto it,
  rebuilt `koruc`, set `TMPDIR=/tmp/cypoe012` for a private cache.

## Cluster map (measured, not claimed)

| Cluster | Tests | State | Mechanism |
|---|---|---|---|
| Loops / back edges | 330_084/085/086 | **green** | Per-loop obligation ownership holds; rejections (330_075) and carries both work. |
| Borrow | 330_091, 335_046 | **green** | 091 enforces under `--auto-discharge=disable`; 046 auto-discharges a borrowed continuation. |
| Error branches | 335_006/007 | **parked** | Auto-heal real: verified by respelled probe — inserter emits `disconnect(conn: c)` into the `| err` arm, prints "Disconnecting". REFUSE-vs-HEAL ruling deferred to Lars (TODOs, 2026-10-15). **Bonus finding: committed fixtures are grammar-dead** — db.kz uses pre-KORU021 single-branch-payload decls (PARSE003); they can't run as committed and need the 330_027-style respell before any ruling lands. |
| Error branches | 335_022/023 | **green** | Use-after-discharge on LIFO violation is caught. |
| Taps | 330_030/031 | **green** | Compose with auto-discharge + binding substitution. |
| Wildcard metatypes | 330_009/010 | **green** | |
| State variables | 522/523/524/525 | **green** | `M'_` wildcard, `M'owned\|borrowed` constraint, chaining all work; 524's violation refused. Cluster was fully fixed before this round. |
| Singles | 330_019/050/076, 910, 335_044 | **green** | 076 header already documents the fix (jump-arg crediting). |
| 330_120 | warm-up | **green** | Fix already landed (`c15f4c368`: `rebindObligationDiscard` mints `_auto_N` for terminal unbound returns — code comment narrates it verbatim). |
| Pin rot | 330_060, 210_014 | **was red, now green** | Not compiler failures. Both pinned `error\[KORU\d+\]`; harness `check_expected_patterns` runs `grep -E`, where `\d` = literal 'd' (grep 3.4 supports `\w`/`\s`, NOT `\d`). Pin could never match → false wrong-error. Fixed `0517d11e1`. |
| Fold arm-exit drop | 330_078 | **parked — premise arguably wrong** | See below. |

## 330_078 — located mechanism (the one real residual)

Claim: `#loop` carries `<!owned>`; `| stop r -> r` drops it, compiles+prints.

Measured: still compiles/prints (real). But the drop is **invisible to the
checker by contract, not by a missing check**:

- `step` declares `h: *Handle<!owned>` — a consume param. Consume-at-door IS
  the discharge (330_076's "host proc is trusted" ruling). On the `| stop`
  iteration the obligation legally terminates inside `step`; no live
  obligation ever reaches the arm.
- Proof the arm-exit check exists: respelled probe with `| stop
  *Handle<owned!>` payload and `| stop h2 |> report(n: 0)` under
  `--auto-discharge=disable` → `error[KORU030]: Resource 'h2' carries
  obligation <owned!> was not discharged` at the arm's line (twin of 330_127
  under a fold). Runtime leak lives only inside step's Zig body.
- Open question for Lars: may a fold-step's consuming param absorb the carry
  on a non-reissuing branch? If yes (current contract), the pin's premise is
  wrong — delete or respell to the h2 shape, which already refuses correctly.

## Landed

- `0517d11e1` — `error\[KORU[0-9]+\]` in
  `330_060/expected_patterns.txt` and `210_014/expected_patterns.txt`.
  Verified: `./run_regression.sh --no-rebuild --allow-concurrent --parallel 4
  330_060_reject_state_mismatch_on_input 210_014_void_chaining_nested` → 2/2 PASS.
- Branch carries `9125d583b` (sibling's env commit) as base.

## TODO-edit denial

Attempted to persist the 330_078/335_006/007 diagnoses into their TODO files;
writes denied by sandbox rule. Diagnoses live in this report instead.

## `--no-verify` usage

Commit used `--no-verify`: the pre-commit invariant gate fails on
`error[KORU002]: module not found: 'koru/odds'` — `koru/odds` is the judged-row
backend, explicitly not provisioned in this clone per the prompt. The
deterministic rows (git-wall) passed. Row named: **invariant gate /
koru-odds judge module**.

## New issues filed

None — no new compiler gaps found. The REFUSE-vs-HEAL ruling (335_006/007)
and the 330_078 contract question are already parked in-repo for Lars; the
fixture-staleness note is reported above rather than filed since it belongs
to the same parked decision.
