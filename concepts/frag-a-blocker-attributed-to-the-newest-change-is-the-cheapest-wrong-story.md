---
type: belief
id: frag-a-blocker-attributed-to-the-newest-change-is-the-cheapest-wrong-story
provenance: `-> verdict { … }` was recorded as the named-single-outcome feature's remaining blocker. It is a pre-existing collision: a braced produce has never worked on ANY event, including an ordinary two-branch one. Diagnosed 2026-08-08; the pin is 210_190
ts: 2026-08-08
---

# A blocker attributed to the newest change is the cheapest wrong story available

I shipped a surface change, hit a refusal in a program using it, and wrote the
refusal down as that change's remaining limitation. It was not. **A braced
produce — `-> name { field: value }` inside a branch arm — has never worked on
any event**, named single outcome or not. An ordinary two-branch event fails
identically.

The attribution was free, plausible, and wrong. Free because the new thing was
right there; plausible because the failure only ever appeared in programs using
it; wrong because nobody had checked the shape *without* it. **The control took
ninety seconds and I ran it a day late.**

The cost is not the ninety seconds. It is that the note went into a test comment
and a handoff as "this feature's blocker", which sends the next reader to the
feature — where there is nothing to find — instead of to a collision in the
produce position that predates it by months. **A wrong story about a defect is
more expensive than no story**, because it is actionable, and the action is
wasted.

The tell was audible and I heard it without listening: my first attempt collided
with `std.testing:ok`. A branch constructor has no business being resolved
against the standard library at all. That single line said "this is being read as
an invocation" before any of the archaeology, and I treated it as a naming
inconvenience and renamed the branch.

**The rule: before recording a limitation of a new thing, write the same shape
without it.** If it still fails, the new thing is a witness, not a cause — and
the honest note points at the older mechanism. This is the diagnostic twin of
[[frag-a-dedup-key-must-be-an-identity-not-a-spelling]]'s lesson about failures
surfacing far from where they break: a defect does not fail where it lives, so
the newest code in the stack trace is a terrible prior.

Related, from the same day and the other direction:
[[frag-a-portability-layer-is-the-thing-that-does-not-port]] — there the newest
work was blamed too little, and a consumer's own bug was filed as a compiler
defect. Both are the same failure to ask *whose* bug this is before writing it
down.

## 2026-09-10 — the biggest diffstat is the same trap, one door over

Eight `part` tests went green→red between two boards. I proved they were not my
change (reverted my `src/`, rebuilt, re-ran one — still red) and then named a
culprit anyway: `ab7b907fb`, because `git show --stat` showed `src/parser.zig
+215` and it was a parse-time gating change. A satisfying story.

Wrong commit. The bisect: `ab7b907fb` **passes** the failing test; `f359af2bb`,
the next commit, **fails** it — by deleting two lines while adding a
`report_gates` parameter (`try all_parts.appendSlice(parse_allocator,
primary.parts);` in `mergeEntryCompanions`, and `defer parser.deinit();` in
`main.zig`), so the entry's own `part` declarations never entered the merge list.
I wrote the wrong hash into a **pushed** commit message before running the
control, and only bisected after being asked.

So the prior is wider than "newest". **The most plausible-looking change is not
the cause either — a big, on-topic diff is exactly as free a story as the newest
commit.** Both are cheap to say and neither is evidence. The rule generalizes
cleanly: **no name without a bisect.** A diffstat is a lead; the compiler built
at that commit, run on the failing test, is the proof. And a wrong hash in a
pushed message is worse than no hash, because the next reader follows it to a
commit that is innocent.
