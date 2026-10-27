# fleet — autonomous challenge runs

`Cypoe/challenges-orchestrate` tracks the overnight challenge fleet:
per-challenge reports in `reports/`, newly filed briefs in
`new-challenges/` (promote into `challenges/` on main when reviewed).

## Machinery

Driver lives OUTSIDE the repo at `W:\src\koru-fleet\`:

- `loop.sh` — serial round-robin. Picks a standing challenge (from
  `origin/main:challenges/` + `fleet/new-challenges/`), opens a
  worktree at `W:\src\koru-wt\<slug>` on `Cypoe/challenge-<slug>`,
  runs `devin -p` with `prompt-template.md`, classifies via
  `state/result-<slug>.json`, pushes the branch + opens the PR on
  success, commits reports/ledger here. `touch W:\src\koru-fleet\STOP`
  halts after the current round.
- `prompt-template.md` — the per-round brief: doctrine, the WSL/zig/env
  recipe, commit-hook recipe, result-file contract.
- `state/ledger.tsv` — one row per attempt: challenge, status, branch.
- `logs/` — `devin --export` transcripts.

## One-time setup

1. Auth the headless CLI (it does not inherit the IDE session's login):

       "C:\Users\fabi0\AppData\Local\Programs\Devin\resources\app\extensions\windsurf\devin\bin\devin.exe" auth login

2. Build the reference `koruc` once in this worktree (WSL, with
   `KORU_BACKEND_TARGET` + `/tmp` cache dirs) so `loop.sh` can seed it
   into each challenge worktree.

3. Start: `bash W:\src\koru-fleet\loop.sh` (Git Bash; it never returns
   — run under `nohup`/tmux or a dedicated terminal).

## Rules the fleet holds itself to

- A challenge is a generator; the yield is a fix, a pin, an instrument,
  or an honest "already fixed". Stale-claim measurement is a result.
- Toolchain defects outrank new work 10,000x.
- Agents commit only on the challenge branch; the driver publishes.
- New gaps get filed as briefs in `new-challenges/`, not chased
  mid-round.
