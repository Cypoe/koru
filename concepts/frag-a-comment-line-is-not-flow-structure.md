---
type: belief
id: frag-a-comment-line-is-not-flow-structure
provenance: the intranquil-domain wild flows (tests/session.k, tests/arrangement.k, 2026-09) kept hitting KORU010 "comment line inside a flow chain" — section narration had to be deleted or flattened into trailing comments to keep chains alive.
ts: 2026-09-22
---

# A comment is trivia between chain steps — only the dispatch block may not be split

`//` lines between `|>` continuation steps were refused outright (KORU010),
and blank lines split chains the same way. The consequence was not
cosmetic: a long orchestration — the thing flows exist to express — could
not carry section narration, so realistic flows compressed into one
uncommented column of invocations, or the author wrote comments and
deleted them.

**Resolved 2026-09-22**, and the resolution kept the part of the refusal
that was a ruling rather than an accident. `chainCommentDisposition`
classifies by what the comment precedes: before a `|>` step it is trivia
and the chain survives (`210_239` green); before a `|`/`!` handler arm it
still refuses — the dispatch block is a single visual unit and `510_080`
pins that refusal. Blank lines still split chains — a blank is a visible
separator the author chose, not invisible trivia; widening that is its own
decision, not this one's.

Related:
[[frag-a-modules-flows-are-two-temporal-classes]] — the flow/statement
boundary this wart compounds: comments can't split chains AND phantom
obligations auto-discharge at statement end, so a narrated session has no
legal shape at all today.
