---
type: belief
id: frag-a-drifted-installed-hook-enforces-yesterdays-law
provenance: koru session 2026-09-26 — cross-repo drift census: koru-libs and kopium ran stale .cjs payloads for weeks (missing the merge exemption, still carrying the dead queue leg); repaired and pinned by installed-hooks-match-source / consumer-hooks-match-source
ts: 2026-09-26
tags: [koru, hooks, enforcement, drift, membrane]
---

# A drifted installed hook enforces yesterday's law

`hooks/` is tracked and canonical; `.git/hooks/` is untracked and is what
actually runs. Between them sits nothing — until a check is written, an edit
to the tracked source simply never reaches the enforcement, and the commit
record says the new rule while the hook enforces the old one. Measured
2026-09-26: koru-libs and kopium carried payloads a month stale — the
merge-commit exemption missing, the dead inbox-queue leg still present —
and no gate, diff, or alarm noticed.

## The ruling

- **In the canonical repo, byte-identity is the rule** — every tracked hook
  (the installer excepted) must match its installed copy; a lost exec bit is
  drift too.
- **In consumer repos, only the payloads are shared law.** Shims legitimately
  vary: a consumer's pre-commit calls `gate.py --repo`, another repo may run
  its own dispatcher entirely (6digit-world's `post-commit.d/` is a different
  lineage, not drift). The `.cjs` files carry the membrane gate and the
  signal surface — those are what must match.
- **The check inherits one blind spot, named not hidden:** it runs inside
  pre-commit, so a missing pre-commit is unreachable by construction.

Also measured this session: the audit itself can lie by a cheap path bug —
`git rev-parse --git-common-dir` returns a *relative* `.git`, and a script
that runs it from the wrong cwd diffs a repo against itself and reports
"in sync" for everywhere. The catch was checking file sizes after trusting
the diff. Verify the verifier.
