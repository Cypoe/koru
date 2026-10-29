---
status: standing
kind: env-defect
---
# CRLF checkouts poison every assertion-bearing negative test (`wrong-error`)

Fleet clones check out the tree with CRLF line endings (this host:
`/mnt/w/src/koru-wt/*`). `check_expect_assertions` in
`scripts/regression_lib.sh` reads `EXPECT` lines verbatim — a trailing `\r`
rides inside every `CONTAINS`/`NOT_CONTAINS`/`ERROR_AT` substring, and
`grep -qF 'substr\r'` never matches the LF `backend.err` the compiler writes.

Measured 2026-10-29 on `023-the-diagnostic-site-audit` (base 9f8576850):
4/4 assertion-bearing negative tests failed `wrong-error` with byte-correct
diagnostics in `backend.err`; LF-normalizing the three control `EXPECT` files
flipped all three green with zero compiler change. The CRLF tree also makes
`git status` show ~9k modified files (line-ending-only diffs), so a round's
real edits hide in noise.

Yield: either normalize `check_expect_assertions` to strip `\r` from EXPECT
lines (one-line fix in regression_lib.sh — the enforcer's own predicate, so
verify against the harness), or make fleet clones check out with
`core.autocrlf=false` / `-c core.eol=lf`. Same host-drift family as
`backend_target_env_gap` — possibly fold into one env-hardening brief.
