---
type: belief
id: frag-the-shared-checkout-overwrites-silently
provenance: 2026-09-24 — two sessions worked one checkout for ~105 minutes (commit range ebaa7c744..e730148bf); the night's failure inventory is held as a dated evidence bundle in the korulang_org draft `two-agents-one-worktree`, deliberately not restated here
ts: 2026-09-24
---

# A shared checkout fails silently — git's conflict machinery lives at merge boundaries, not at write time

**The belief.** Two agent sessions writing the same working tree produce a
failure class git cannot see. Conflict detection exists at merge boundaries —
checkout, rebase, stash pop — but the actual hazard is *at write time*: an
agent's whole-file write between another session's read and write wins with
no record, because a file unchanged in the index is a file nothing watches.
The same assumption hole opens a second cell beside the worktree: the index
itself, where staged sets interleave, resets clear them without notice, and
HEAD moves between stage and commit.

**The measured inventory** (one night, two sessions, three shared files —
evidence bundle cited above, not duplicated): silent overwrite of applied
hunks; a `git stash` that captured the other session's mid-write rewrite and
would have double-applied it; index races including a `reset` that cleared a
staged set; a half-written `src/` file read as a latent compiler defect; and
a `koru_std/` edit landing while the other session's suite was live.

**What held.** Not the checkout — the walls built for other reasons: the
suite lock, the line-count pins, the commit-msg judges. They force
verification at exactly the seams where concurrency lies. Everything else
that caught a loss was habit (re-grep before staging, selective staging,
re-verify after any pause), and habit is not an invariant — a session with
ordinary discipline ships the silent loss.

**The ruling (Lars, same night).** The fix is worktree enforcement, and the
gap is enforcement friction, not a design objection. That reframes the fix
from "build isolation tooling" to "default the mechanism already owned" —
and shifts the honest question to the one thing a worktree does not
isolate, the compiler sources reached through `/usr/local/lib/koru/src`
([[frag-a-worktree-isolates-the-tree-not-what-resolves-absolutely]] — the
same boundary, leaking inward).

## Where this is wrong, if it is

- If sessions run in worktrees by default and the failure inventory still
  produces silent losses, the "shared cell" mechanism claim is wrong —
  `correct`, not caveat.
- If a write-time content guard (hash-check since last read) lands and the
  silent-overwrite class disappears *without* worktree discipline, the
  enforcement framing was overstated — `evolve`.
- If the blog-draft framing turns out to be the durable artifact and this
  file drifts, that is the membrane's own duplication failure — the frag
  should be corrected to a pointer and the post promoted.

Related: [[frag-a-worktree-isolates-the-tree-not-what-resolves-absolutely]],
[[frag-a-board-measured-on-a-dirty-tree-is-not-reproducible]],
[[frag-a-green-run-is-evidence-about-the-tree-not-the-commit]].
