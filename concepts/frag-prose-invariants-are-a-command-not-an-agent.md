---
type: belief
id: frag-prose-invariants-are-a-command-not-an-agent
provenance: designed and hand-measured 2026-07-26 (Lars + Claude) — 17 rules extracted from the three CLAUDE.md files and run by hand over 30 commits; two findings survived, one of which was a test comment written twenty minutes earlier in the same session
ts: 2026-07-26
---

# A prose invariant is an obligation whose discharger is not the compiler (belief)

Some rules we hold cannot be walls. "Did this code use the library, or hand-roll
what the library provides?" is not an expensive static check — it is not a static
check at all, because it asks about intent against the whole stdlib surface.
`koruc` has no business answering it, and the pressure to make everything a wall
is wrong at exactly this boundary.

The shape that fits: an obligation the compiler emits and cannot discharge. Koru
already has obligations, discharge, and narrowing. This adds one class where the
witness is something that reads.

## The command emits a document; it does not reason

`koruc <file> vouch` collects — it never fires an agent. It walks the AST, selects
the invariants in scope, and emits a work-document. Whatever consumes that
document decides scope (a diff, a subtree, the whole program) and does the
reasoning. The toolchain stays deterministic and acquires no LLM dependency; the
non-determinism lives entirely outside it, in the consumer.

This is not a new compiler feature. `~std/compiler:command.declare` already lets a
library register a `koruc` subcommand, and `koru_std/explain.kz` is the working
precedent: a comptime command that runs *instead of* compilation with full AST
access. `vouch` is the same animal, and the payload format is a Source block,
which already parses.

## Two classes, and they are not the same check

- **Rules** are normative — "don't do X" — sourced from CLAUDE.md and from here,
  and checked against a **diff**. The strongest of them are about a *change*
  rather than a state: green-by-edit is a claim about the relationship between two
  hunks in one commit, which no linter can express.
- **Claims** are descriptive — a comment asserting something about the code it sits
  on — and checked against **adjacent evidence**. Cheaper and far more
  conclusive, and needing no declaration: every comment in the corpus is already
  one. A single rule covers the whole class, and it is probably the most valuable
  entry: *a comment's claim must be true of the code it sits on.*

Selection is by annotation, not by config: a diff touching `[comptime]`
declarations pulls the comptime-scoped invariants. That is the open-metadata
ruling doing what it is for — `vouch` is another pass that interprets an
annotation.

## Where the corpus lives

In the membrane, not in a new store. The intake litmus here — *if the code and its
tests were the only artifact left, would this be lost?* — does not merely permit
prose invariants, it **selects** for them: one exists precisely because it cannot
live in the suite. A fragment becomes live by growing a `vouch` header naming its
scope; an AST annotation says only that a declaration is in scope for a named
fragment, and never restates the rule, or the prose rots in two places at once.

The lifecycle event worth the most is an invariant **retiring because a wall
finally got built**. That is a repudiation with a lineage trailer, which this
corpus already models.

## The measured seed, and what it caught

Seventeen rules were extracted by hand from the three CLAUDE.md files — twelve
with a cheap mechanical pre-filter, five purely semantic — and run over 30
commits (2,863 authored added lines, after excluding generated bulk). Two findings
survived verification. Neither was reachable by any static check, and both were
comments making false claims about code:

- A control test asserting a sibling pin's red state **and its stated cause**. The
  sibling went green three hours later, in the same session, from another agent's
  fix. Both halves of the sentence were false by nightfall.
- A test comment asserting a transform-ordering mechanism, written twenty minutes
  earlier in the session that then caught it. The outcome it pinned was correct;
  the mechanism it named was unestablished. It now states the outcome and files the
  mechanism as open.

The second is the one that matters. The corpus caught its own author, inside an
hour, on prose that read as careful and specific. That is the argument for the
whole thing, and it is also why the rule about comments outranks the rest.

## What follows

- **A prose invariant does not relieve the pressure to build a wall**, but the
  question to ask it is *has a wall become cheap?* — not *could this be a wall?*
  Usually the answer is no, and the invariant simply stays.
- **The first entry is self-policing**: *do not keep in prose what belongs in a
  test.* The corpus governs its own growth with the same checker, rather than
  relying on anyone's discipline.
- **Every mechanical pre-filter carries a positive control** —
  [[frag-a-check-that-cannot-match-reports-clean]] is why, and it was learned the
  hard way during this very measurement.

## Open

Nothing is built. `std/vouch` is a name and a shape; the name overclaims slightly
and was chosen because the defining property of these rules is that they *cannot*
be proven — someone attests. Whether the emitted document should carry the prose
verbatim or a reference the consumer resolves is unsettled, and it decides whether
the document is self-contained or merely a manifest.

## 2026-10-14 — the agent has to reach the decl it guards (pass graph, rung 2)

The `requires`/`preserves` wall on `[transform]` decls landed with a discovery
that is this belief at one remove: rung 1s

## 2026-10-14 — the agent has to reach the decl it guards (pass graph, rung 2)

The `requires`/`preserves` wall on `[transform]` decls landed with a discovery
that is this belief at one remove: rung 1's seeded edges on `compiler.kz` were
**dead assertions for a full rung** — `pass_graph.collect` iterated top-level
items only, and every compiler pass decl lives inside a `module_decl`, so the
graph validated an empty edge set. A checker that never reads the decls it
guards is prose wearing a wall's clothes: it LOOKS enforced, and that is worse
than the comment it replaced, because the comment at least admitted it was a
claim. The fix was one line of recursion — the belief it confirms is that an
annotation is not a contract until the thing that reads it is counted, and the
count has to cover where decls actually live.

The same rung added the second half the instrument was missing: `preserves`
declares the *allowed* set (which top-level item kinds a whole-program
write-back may not touch; `!kind` atoms mean "all except these", closed under
vocabulary growth), KORU181 enforces it inside the backend run, and the Lean
oracle re-decides compliance from the committed kind tags — the declared
surface, the enforcement, and the independent check now name the same bound.
