---
type: belief
id: frag-a-surface-ships-when-the-toolchain-makes-it-cheap
provenance: 2026-09-06 session with Lars — the `part` design conversation, provoked by store.kz at 11,985 lines (25% of koru_std) and the question "how do we get *you* to actually use it?"
ts: 2026-09-06
---

# A split surface is adopted when the toolchain makes it the path of least resistance

Koru files accrete to 12K lines not because agents are lazy but because the
split rules are **implicit**: stem facets join silently (a misnamed sibling
just never gets picked up), submodules require a directory and change public
surface, so "create a new file" is a guess about whether the compiler will
honor it — while appending to the known-good file always compiles. Both
agents and humans converge on the big file. That is a rational equilibrium,
and the fix is to make discovery **declared and loud**: `part query` in a
module file names its sibling group, and a tag with no file is KORU201 —
never a silent miss. The declaration exists only to convert a silent failure
into a named one (140_023 pins the refusal).

The second half is the adoption lever, and it is the half that decides
whether the feature lives: **a language surface exists in the compiler only
if something makes reaching for it the cheapest way to get green.** For
agents this means a wall — the git-wall growth gate that baseline-pins each
Koru file's line count, refuses growth, and answers the refusal with the
exact `part` to create ("store.kz pinned at 11,985; grew to N — split the
new event: `~part query` → `store.query.k`"). A feature a wall never forces
is a feature only humans who read the docs will use, and the humans who read
the docs are not the ones appending. The litmus for any new surface is the
question Lars asked: "how do we get the agent to use it?" — and the answer
is walls with teaching, not documentation.

Two rulings that came out of the same conversation, kept here because they
are the *why* the code's flatness enforces:

- **Parts are flat, by construction.** A part file may not declare parts
  (140_028). Parts are file-splitting only — not a second module system. The
  promotion path for a part that outgrows its file is the existing directory
  module tree. One level of indirection keeps "where does new code go"
  answerable, which is the point of the feature.
- **The join is AST-level, never text-level.** Each part parses with its own
  path; locations and hostline routing survive (140_027, 140_022). C-style
  text `#include` was refused precisely because it flattens locations onto
  the including file — the mechanism had to keep what the facet merge
  already preserved.

What would correct this: `part` ships, the growth wall ships, and agents
still append to store.kz (the wall is noise, not teaching) — or a future
surface is adopted with no wall at all, which would falsify the claim that
the wall is load-bearing. The counter-observation is the wall's own
baseline shrinking as files split.
