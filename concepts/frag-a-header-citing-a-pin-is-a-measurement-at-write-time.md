---
type: belief
id: frag-a-header-citing-a-pin-is-a-measurement-at-write-time
provenance: created 2026-08-23 for package/test header comments citing red pins as live walls; widened 2026-08-31 to any cross-session claim, after a read-only architecture review (2026-08-30) measured a tree the purge commit (becc6a7f, 2026-08-31) moved within hours; widened 2026-09-14 to grammar-narrating comments, after an agent generated two dead import spellings from them mid-session
ts: 2026-09-14
---

# A claim about this repo — header, review, report — records a measurement at write time; the tree moves

Package and test headers (`draw_per_entity.k`, `bounce.k`, `boids.k`, …) cite
pins: "`690_252` must be red until X". When `690_252` later flips SUCCESS, the
comment does not update — nothing updates it. The result is a corpus of stale
walls: agents read the header, believe the gap is open, and spend a session
building around a refusal that no longer exists.

The same holds for any artifact from another session: a scan, an architecture
review, a report. It measured a tree at a moment that has since moved. Measured
2026-08-31: a review generated 08-30 listed committed `src/*.bak` files and a
holey `.gitignore`; the purge commit `becc6a7f` deleted the files and closed
the holes before the review was a day old — its file list was true at write
time and false within 24 hours. Its "dead code" list, checked against the
current tree, named modules that are live on the second clock — the backend
graph in `koru_std/compiler.kz` / `koru_std/build.zig`
(`frag-zig-build-does-not-compile-all-of-src`). A scan that checks only the
top-level build cannot see them.

The suite is the only authority. A file header that cites a pin is a comment,
not the suite; `SUCCESS` on the cited test does not refresh the comment. A
review is the same comment, longer.

Measured 2026-09-14: **grammar narration in code comments is the same class,
and its cost is generation, not just reading.** The import surface had three
layers of dead spelling living in comments alone — a rejected prefix, a
never-parsed alias form, quoted paths — plus a vestigial variable name that
asserted a resolution step which no longer happens. An agent asked about import
syntax produced both dead spellings mid-session, citing them as live, because
the comments were the only artifact consulted. A comment describing *syntax* is
worse than one describing *state*: a stale state claim misleads a reader, a
stale grammar claim is compilable-looking input the next agent emits verbatim.
The detector generalizes: any comment that names a user-facing spelling is a
claim the parser either enforces or doesn't — grep the spelling against the
suite, never the comment.

## The rule installed

Before spending a session on a claimed gap — from a header, a review, or
another session — check the claim **in this session**, against the current
tree, and lead with exactly one of three claims:

- **blocker** — you compiled it; it refused (quote the diagnostic).
- **not a blocker** — you compiled it, or a passing test *is* that join.
- **unmeasured** — you have not compiled it this session. Stop talking.

When you *produce* a scan or review, pin the tree you measured (`git rev-parse
HEAD` + branch) at the top — without a pin, staleness is invisible, and the
reader cannot tell a claim about a dead tree from one about this one
(`frag-a-measurements-provenance-is-reachability-not-existence`).

## Open questions

- Whether a mechanical wall (grep for pin-citations in headers, cross-check the
  snapshot) should flag stale citations the way prose-check flags dead claims,
  or whether the three-claim discipline is enough.
- Whether unpinned scans/reviews should be refused at intake ("no tree pin, no
  reading"), or whether the discipline is enough.
- Whether headers should cite pins at all, or name the *behavior* and let the
  suite carry the verdict.

## Severs

Nothing — this sharpens, rather than repudiates, the HOSTING.md pattern
("claims written where only measurements belong"); that pattern stays about
prose documents, this one is about claims about the repo itself.
