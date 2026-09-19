---
type: belief
id: frag-a-comment-line-is-not-flow-structure
provenance: the intranquil-domain wild flows (tests/session.k, tests/arrangement.k, 2026-09) kept hitting KORU010 "comment line inside a flow chain" — section narration had to be deleted or flattened into trailing comments to keep chains alive.
ts: 2026-09-22
---

# A comment inside a flow chain terminates the chain — trivia is being parsed as structure

`//` lines between `|>` continuation steps are refused outright (KORU010),
and blank lines split chains the same way. The consequence is not cosmetic:
a long orchestration — the thing flows exist to express — cannot carry
section narration, so realistic flows compress into one uncommented column
of invocations, or the author writes comments and deletes them. The
diagnostic is deliberate, which makes it a designed limitation rather than
an accident — and the limitation is still wrong: a comment is trivia, and
the grammar that attaches structure to it is the thing that should change.
Pinned red aspirational: `210_239_comment_inside_flow_chain`.

Related:
[[frag-a-modules-flows-are-two-temporal-classes]] — the flow/statement
boundary this wart compounds: comments can't split chains AND phantom
obligations auto-discharge at statement end, so a narrated session has no
legal shape at all today.
