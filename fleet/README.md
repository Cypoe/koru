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

1. Install + auth the WSL-native CLI (the Windows devin.exe can't
   sandbox; the Linux one can, and the whole round runs inside WSL):

       wsl -e bash -c "curl -fsSL https://cli.devin.ai/install.sh | bash"
       wsl -e bash -c "~/.local/bin/devin auth login"
       wsl -e bash -c "sudo apt-get install -y bubblewrap socat"   # for --sandbox

2. Reference `koruc` already built at `W:\src\koru-orchestrate\zig-out\bin\`
   (origin/main, WSL zig 0.15.1) — loop.sh seeds it into each clone.

3. Start: `bash W:\src\koru-fleet\loop.sh` (Git Bash; it never returns
   — run under `nohup`/tmux or a dedicated terminal).

## Containment model (probe-verified 2026-10-28)

Each round clones the repo (`git clone --shared`) into
`W:\src\koru-wt/<slug>` — `.git` inside the workspace, so the sandbox can
deny the whole main tree without carving a hole for worktree metadata.
The agent runs `devin -p --sandbox` (Autonomous + bwrap). Measured:

- Workspace writes work; `git add`/`commit` work; `.git/hooks/` itself
  is read-only even inside the workspace (hooks can't be tampered).
- Ungranted paths: `Read-only file system` — verified against
  `W:/src/koru` and `koru-fleet` pre-grant.
- **Sandbox writable roots come from USER-level config only**
  (`~/.config/devin/config.json`): project-config `Write` allows
  grant tool permission but did NOT widen sandbox roots (measured —
  `touch` in an allowed-but-ungranted dir → ROFS). Fleet grants live
  in the WSL user config: `/tmp`, `~/zig*`, `~/.cache`, `koru-fleet`,
  `koru-orchestrate/fleet`.
- `Read(...)` denies hide `.ssh`, `.aws`, gh creds, devin creds
  (tool-level deny, verified).
- `Exec(...)` rules are **prefix** matchers — `Exec(git push)`, never
  `Exec(git push *)`. And pushes have a second wall regardless:
  WSL git has no GitHub credentials (verified — fails on auth).
- `sudo` is dead inside bwrap (verified); `gh` isn't installed in WSL.
- Windows interop binaries (`node.exe`, `git.exe` shims) execute fine
  under bwrap+drvfs (verified).

Fails closed: no bwrap/socat → the session refuses to start.

## Rules the fleet holds itself to

- A challenge is a generator; the yield is a fix, a pin, an instrument,
  or an honest "already fixed". Stale-claim measurement is a result.
- Toolchain defects outrank new work 10,000x.
- Agents commit only on the challenge branch; the driver publishes.
- New gaps get filed as briefs in `new-challenges/`, not chased
  mid-round.
