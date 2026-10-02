---
challenge: the-last-interpreter
kind: frame
status: standing
yields: "one external instrument retired — a Python or shell step in the toolchain's enforcement path replaced by an in-language surface that produces verdict-equal output on the same input, with the old file deleted or demoted to read-only oracle"
family: toolchain
created: 2026-10-02
---

*Walker context — the recurrence that earned this frame. The toolchain has a
second interpreter in it, and it has been ported twice by hand already:
`invariants` collection moved from stdout-scraping Python to `std/invariants`,
and `gate.py`'s semantics — checks, odds rolls, `-local` scoping, `repo-X`,
the Jev judge, the credential provision, the 96KB bound — moved into
`std/gate` + `git-gate` (`b933e8945`). Both ports paid the same tax: the
semantics had to be re-derived from a script the language couldn't see. The
third and fourth instances are already visible — `git_wall.sh` still stands
as the hook's first line, `invariants/checks/*.py` are the instruments the
in-language gate now shells out to. The shape keeps recurring; the recurrence
is the promotion.*

*This frame is the exhale the toolchain keeps promising: every enforcement
surface the project depends on becomes a surface the compiler can see,
check, and mint. The catalog that grows is the graveyard — one row per
retired instrument, in reverse order of "things a stranger would believe
this toolchain needs Python for."*

---

## The brief (sealed — you are the contestant)

The enforcement path still contains external interpreters. The candidates,
most-load-bearing first:

- **`invariants/gate.py`** — the reference runner. `std/gate` already
  reproduces its semantics in-language; what remains is the swap itself:
  the hook's second line becomes `koruc invariants/invariants.kz gate
  git-gate`, gate.py is deleted or demoted to a read-only oracle comment
  names. The keystone replay — do this one first.
- **`git_wall.sh`** — the hook's first line, the .gitignore oracle. It is
  deterministic and small: a `check:`-shaped instrument in-language, or a
  row in the manifest.
- **`invariants/checks/*.py`** — the real instruments (emitted-while,
  call-valued-index, deslop census, stamps, hooks-match, signal
  vocabulary). A check: field execs a command; the port target is a Koru
  binary — `koruc build checks/<name>.k`, the field updated to the binary.
  One script per replay; do NOT batch.
- **Anything else a `prose grep` or hook file names** — the list above is
  a floor, not a ceiling; a surface you find beats a surface you were
  handed.

For your one pick:

- **Verdict-equivalence is the done-bar, not "it compiles."** A/B the two
  implementations on real inputs: same staged diffs, same repos, same rows.
  For gate.py: run both runners over the same staged state and diff the
  verdicts row-by-row. For a check script: same tree, same exit codes on
  fixtures including the BROKEN/self-test path. A port that changes the
  verdict shape is a new instrument — that is a design conversation with
  the walker, not a replay.
- **Honesty ports, not just behavior.** If the Python reports BROKEN,
  UNJUDGED, or refuses, the in-language form must report the same states
  for the same causes — a port that turns "cannot verify" into "clean" is
  a regression wearing a refactor.
- **The old file leaves or loses its authority.** Deletion is the honest
  end; if it stays as an oracle, a comment at its head names what replaced
  it and that it no longer runs on hooks. An abandoned script that still
  looks live is a dead instrument mislabeled as infrastructure.
- **Pin it.** A regression test (or an extension of an existing one) that
  would catch a silent revert of the port.

Self-ground before you build: read `std/gate` and the gate profile in
`invariants/invariants.kz` — the surface your port lands on already exists;
the question is which of its rungs your instrument joins. The ledger below
is the catalog — if a surface is already retired, pick another.

## The catalog — retired surfaces

*(first replay measured gate.py against its port — verdict-equal on the
dogfood corpus, divergent on two named edges; not yet retired)*

| surface | oracle | method | verdict | divergences | date |
|---|---|---|---|---|---|
| `invariants/gate.py` → `koruc invariants/invariants.kz gate git-gate [--repo]` | `python3 invariants/gate.py --repo <scratch>` (`GATE_BLOCK=1` ≡ profile `block: true`) | 6 /tmp scratch repos, identical staged diffs, both runners, per-row verdicts + exit codes | verdict-equal on the dogfood corpus (swallow VIOLATION/exit 1 both; lograise & readme clean/exit 0 both; 17/17 rows same verdict class; odds rolls byte-identical on every fetched diff — on oversized the port rolled over an empty fetch, symptom of divergence 2) | **2, named below — blocks retirement** | 2026-10-02 |

### Replay 1 evidence — gate.py A/B, pick5/gate-equivalence

Per-row verdicts on identical staged diffs (koru worktree manifest,
`zig-out/bin/koruc` = 5b4d514ff):

- `swallow` (`except Exception: pass` staged): `no-fallbacks` VIOLATION
  both sides (Jev p=0.94 vs p=0.91 — live-model jitter on the shared
  judge binary; verdict identical). All 12 non-judged rows identical.
  Exit 1 both.
- `lograise` (`except …: log.warning; raise`): all judged CLEAN p=1
  both; exit 0 both. `deslop-stdlib-host-board` rolled 0 < 10 and fired
  in both, then skipped manifest-scoped in both.
- `readme` (doc-only diff): identical, exit 0 both.
- `oversized` (120,118B staged diff): **DIVERGED** — gate.py: 4 judged
  rows `UNJUDGED state exceeds ~96KB`, enforcing → 4 blocking, exit 1.
  koruc gate: judged rows reported "no staged changes" → clean, exit 0.
- `mid` (60,118B staged diff — inside the 96KB judge window): same
  bottom line by accident, divergent accounting — gate.py fetched the
  diff and got 4 live Jev verdicts (CLEAN p=0.83–1, exit 0); koruc gate
  reported "no staged changes" → clean, exit 0, never judging. Root
  cause for both divergent runs: `helpers.runOut` rides
  `std.process.Child.run`'s default `max_output_bytes = 50KB`; the
  fetch errors, `staged` stays null, and the rows take the empty-state
  path. The >96KB UNJUDGED branch exists in gate.kz but is unreachable
  — the cap strangles the input before the window check, and judged
  rows silently skip on any diff over 50KB. Cannot-verify folded into
  clean.
- `pick5-teaching-surface` (foreign repo sharing the manifest dir's
  basename): **DIVERGED** — gate.py skips manifest-scoped check rows
  (realpath identity); gate.kz:270 tests `basename(gated_repo) ==
  basename(prof_repo)`, so all 7 manifest checks RAN — instrumenting
  the manifest's own tree while reporting against the foreign repo.
  A red manifest check would block an unrelated foreign commit.

Untested seam: BROKEN-manifest path (koruc can't read the listing →
gate.py prints BROKEN + exit 1; the in-language gate fails at compile —
both loud, shape differs, not measured).

Done-gates, all mechanical: verdict-equivalence demonstrated on real inputs
and quoted · honesty states preserved (BROKEN/UNJUDGED/refusal) · old file
deleted or demoted with a naming comment · a pin that catches silent revert ·
catalog row appended.
