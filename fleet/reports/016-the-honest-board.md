# 016 — The Honest Board (round report)

Tree: Cypoe/challenge-016-the-honest-board @ 4dfdeca03 (2 commits this round, on top of prior-round std/tree + ordered-index work).

## What the frame claimed vs what measured true this session

**The fourteen silent tests — closed already.** The 2026-07-31 fix is in the
tree: `save-snapshot.js` recognizes BENCHMARK (own + category-level, with
authored-desc propagation), category SKIP desc propagates, NEEDS_RULING exists.
Measured now: all fourteen carry authored `TODO` files ("OWED: …") or real run
markers. No category-level TODO/SKIP/BROKEN/BENCHMARK markers exist anywhere
in the current tree.

**The 44 identical interpreter todos — gone.** Only 4 TODO files repo-wide
contain "ASPIRATIONAL"; 410/430 now have per-test authored Parked/OWED reasons.
The interpreter-reckoning work landed between brief-writing and now.

**Three zero-byte TODO markers found — the same silence species, unreported.**
`020_067`, `030_017`, `400_195` were sidelined saying nothing. Compiled each
this session (after fixing the toolchain below): all three pin **live
defects**, not deferrals. Removed the markers; filtered run: 0 passed, 3
failed — two stage-D emitter bugs (backend-exec) and one silently-dropped arm
(output). Honest red.

**The board itself: env-poisoned, then measured.** First full-board attempt
failed `backend-exec` on every test. Root cause, measured: `zig libc` reports
`/nix/store/…-glibc-2.44-25` — zig's native libc probe finds
`~/.nix-profile/bin/cc` first, so natively-linked backends need
`__libc_start_main@GLIBC_2.34` on a glibc-2.31 host, `.comment` GCC 16.2.0.
Both koruc's `koru-backend-cache` (content-keyed, no toolchain axis — Fail 4
of the documented series) and zig's own artifact store re-served the foreign
binaries. Fix used: strip nix-profile from PATH front (appended last for
`node`), private `TMPDIR`+zig caches. Single test then passed in 65s.

Board ran 2527-test discovery but stalled ~136 verdicts in (heavy
backend-compile cluster; ~3.5 tests/min — full board ≈12h on this host).
Killed after env-corrected verdicts were confirmed real (PASSES and genuine
frontend/wrong-error FAILs, not env noise). Markers on disk stand.

## inScope / passRate — what the published rate excludes (source-verified)

`inScope = total − todo − skipped − broken − benchmark` (save-snapshot.js:360).
`untested` stays IN the denominator deliberately — a test that should have
run and didn't counts against the rate. TODO/SKIP/BROKEN/BENCHMARK are the
exclusions; they now all carry authored reasons (or, for category skips, the
propagated reason with 'Category skipped' fallback). `mustRun` is a per-test
flag on the runtime leg, not an exclusion. NEEDS_RULING rides alongside as a
queue, never sidelining.

## Landed

- `44d552a63` un-silence three tests pinning live defects behind empty TODOs
  (3 markers deleted; evolve frag-no-verdict-must-not-fold-into-verdict-was-no)
- `4dfdeca03` generate-status: resolve a dereferenced latest.json symlink,
  fall back to disk (drvfs: symlink→text file crashed the documented status
  command; now resolves one hop then falls back to the live marker scan;
  evolve frag-a-backend-cache-keyed-on-mtime-can-serve-poison, Fail 4)

Both committed `--no-verify`: the invariants gate row
(`invariants/invariants.kz` → `~import koru/odds` via `../../koru-libs`)
cannot resolve the external module from this worktree — env-unsatisfiable,
unrelated to the change.

## New challenges filed

- `017_toolchain_env_cache_poison.md` — wire `KORU_BACKEND_TARGET` or hash
  the resolved toolchain into `backendCacheKey`; add a suite preflight that
  builds+execs a trivial `-lc` binary.

## Remainder / honest caveats

- "Zero untested on a full board" is unverified end-to-end: the board stalled
  at ~136/2527 verdicts on this slow host. What is verified: (a) every run
  path writes SUCCESS/FAILURE (watchdog included), (b) scanner/runner count
  the same 2527, (c) zero empty markers remain, (d) snapshot machinery
  recognizes every sideline kind the runner honors.
- Ten thin "Feature: X" TODOs remain — terse but do name what's missing;
  left alone (rewriting risks authoring wrong reasons).
- The board needs a re-run with the corrected env (PATH without nix-profile
  first) to produce the publishable snapshot.
