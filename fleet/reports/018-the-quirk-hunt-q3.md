# Report — 018_the_quirk_hunt, item Q3 (command-position swallow)

- Branch: `Cypoe/challenge-018-q3-command-position`
- Commit: `edd3a71a2` (cherry-picked from `d69903ef9` on ccomp)
- Base: `origin/main` @ `9f8576850`
- Status: success (single queue item drained; 018 remains open — Q2, Q4–Q12)

## Claim

`koruc <file> run` compiled and exited 0 without running — the trailing
word hit no declared command and fell through to the normal build.

## Measured at origin/main (this session, WSL zig 0.15.1 build)

Before: `koruc probe.k run` produced `a.out`, printed nothing, exit 0 —
the `run` was silently swallowed. Arbitrary dead words (`probe.k
nonsense`) behaved identically.

## What landed

- `src/main.zig` — after declared-command resolution, an unmatched word
  in command position refuses (exit 1). Leading verbs
  (`run`/`build`/`lib`/`bundle`) get the corrected-order diagnostic;
  other words are named as undeclared with a pointer to `<file> help`.
- `tests/regression/.../310_144_command_position_refuses_dead_words/` —
  pins the three refusals plus controls: `--check`, `deps`, and leading
  `run` all still work. Green under `run_regression.sh`.
- `challenges/018_FIX_QUEUE.md` — Q3 marked drained; the two stale
  "standing leads" (690_109, `/`-in-alias) noted as verified-fixed.
- `concepts/frag-command-position-is-strictly-post-file.md` — evolved:
  the silent-build carve-out no longer exists.

Controls run: `explain`, `claims`, `deps`, `mint`, `glance`, `at`,
`to-k`, `310_123` — all green.

## Caveat

The four judgment gate rows went UNJUDGED on this host — no
`OPENROUTER_API_KEY`, and the LM Studio fallback (`laya`) cannot hold a
~20k-token diff in its 8192-token batch. Deterministic rows all passed.
Re-gate on a provisioned host for Jev's verdict.
