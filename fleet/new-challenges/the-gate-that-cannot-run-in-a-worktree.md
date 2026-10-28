---
challenge: the-gate-that-cannot-run-in-a-worktree
kind: frame
status: standing
yields: the pre-commit invariant gate running (or honestly skipped) from a linked worktree
family: toolchain
---

# The invariant gate cannot run from a worktree

Measured 2026-10-28 on `Cypoe/challenge-002-toolchain-hardening`
(`/mnt/w/src/koru-wt/002-toolchain-hardening`, WSL/drvfs):

`hooks/pre-commit` invokes `koruc invariants/invariants.kz gate git-gate
--checks-only`, but the manifest fails at FRONTEND resolution:

    error[KORU002]: module not found: 'koru/odds'
      --> invariants/invariants.kz:22:1

`invariants/koru.json` maps `"koru": "../../koru-libs"`. From the main
checkout that lands on `/mnt/w/src/koru-libs`; from a fleet worktree at
`koru-wt/<name>/` it lands on `koru-wt/koru-libs`, which does not exist —
the same relative-depth failure class CLAUDE.md documents for `350_013`'s
`../../../../../../orisha/lib` imports. The `koru` alias claims the whole
namespace (`module_resolver.zig` iterates alias_paths and returns
ModuleNotFound without probing KORU_PATH), so `KORU_PATH` cannot rescue it.

Consequence: **every commit in every fleet worktree must `--no-verify` past
the gate** — the deterministic `check:` rows never execute, so the wall
that's supposed to block regressions is structurally dead in exactly the
trees where agents land changes. `gate.py` can't run either — it drives the
same `koruc invariants.kz` compile.

Possible fix directions (unmeasured, pick by measurement): make the alias
search fall through to KORU_PATH when alias_paths miss; teach koruc to
resolve `..`-relative alias paths against a canonical repo root (e.g. the
git common dir, which survives worktrees); or make the manifest tolerate a
missing judge module under `--checks-only` since judge rows are never
reached there. The last one is honest only if the manifest's other imports
stay load-bearing — a gate that skips rows it can't see is the "CANNOT
CHECK" ruling applied honestly.
