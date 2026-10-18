---
type: belief
id: frag-a-judged-state-is-per-file-bounded
provenance: 2026-10-18 — vendoring clay.h (303KB) into koru-libs put the whole staged diff past the judge's measured ~96KB window; every judgment row went UNJUDGED and the commit was blocked on an input limit one file imposed
ts: 2026-10-18
---

# A judged state is per-file bounded — an unholdable file elides to a stub, it does not silence the gate (belief)

The judge's window is a per-input bound, but a commit's staged diff is a
*set* of files. Treating "the diff exceeds the window" as one fact confused
an input limit with a verdict: one vendored header UNJUDGED-blocked every
row, and the remedy the gate printed ("split the commit") was impossible —
a single file past the window cannot be split.

The ruling: a file whose own diff section exceeds the window is elided to
a stub that keeps its `diff --git` header and names the elision and size.
The judges still see that the file was touched — an elision is visible,
judgeable surface, not silence — and can flag one they care about. The
rest of the commit is judged normally; the cap now binds per file, with
the total-diff cap unchanged for ordinary-sized files.

Two corollaries held in the same change. **Local rows are exempt from
elision**: a `git-gate-local` row guards the file it is declared in, and
a stub of that file means the row judged nothing — there, honest
UNJUDGED still stands. **The elision is announced**: gate output prints
each elided path and size, so the narrowing is never quiet.

Open question: whether elided files need their own oracle — a vendored
header's *provenance* (pinned version, checksum) is checkable, and nobody
is checking it today.
