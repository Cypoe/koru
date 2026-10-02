---
type: belief
id: frag-a-command-tor-sees-the-frontends-path-frame
provenance: found by dogfooding — the first real `gate git-gate` run reported
  five green checks as exit-255 failures; traced to location.file's
  frontend/relative frame vs the backend's entry_dir cwd (2026-10-02)
ts: 2026-10-02
---

# A command tor sees the frontend's path frame — the backend runs in `entry_dir`

`flow.location.file` is recorded in the frame the *frontend* resolved it in:
module-resolved files arrive absolute, but the entry file arrives exactly as
spelled on the command line — `koruc invariants/invariants.kz gate …` yields
`invariants/invariants.kz`. The emitted backend, meanwhile, runs with
`cwd = dirname(output)` — inside `entry_dir` already. Any path derived from
the entry's location (`dirname` for a working directory, the file itself for
a `-local` diff) resolves one directory too deep, and a child spawned with
that relative `cwd` fails to exec — surfacing downstream as a bare exit code
far from the cause.

Measured 2026-10-02: `gate git-gate` on `invariants/invariants.kz` reported
five deterministic checks as `check failed (exit 255)` — every one of them
green from a shell. `prof.dir` was `"invariants"`, the child's cwd tried
`invariants/invariants`, `Child.run` threw, and the failure read as if the
instruments themselves were broken. Judged rows silently degraded the same
way: `git -C invariants` failed, the staged diff came back empty, and every
judgment row reported `no staged changes` — a quiet false-skip, the worst
shape a gate can take.

The recovery: a non-absolute `location.file` *is* the entry file (imports
always resolve absolute), and `compiler_env.json` — already loaded at backend
startup — carries its absolute form as `entry_file`. Substituting it at
collection normalizes every derived path without knowing the compile-time
cwd at all.

Open question: whether other command tors (`invariants`, `explain`,
`commands`) derive cwd or relpaths from `location.file` the same way — the
trap is structural, not gate-specific, and each consumer has to hit it
individually until someone greps for the pattern.
