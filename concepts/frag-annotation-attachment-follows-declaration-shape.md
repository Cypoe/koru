---
type: belief
id: frag-annotation-attachment-follows-declaration-shape
provenance: koru/stack first pass with Devin 2026-10-03 — depends_on edges silently empty until the collector read both attachment points
ts: 2026-10-03
---

# Annotation attachment follows declaration shape; a collector must union both (belief)

The same `[depends_on("db")]` entry lands on **two different AST fields**
depending on how the declaration is spelled:

- `.k` head-declarations (`[ann]mod:tor(args) { ... }` at item level) carry it
  on `flow.annotations`.
- `.kz` invocations carry it on `flow.inv().annotations`.

A collector that reads only one silently sees nothing — not a refusal, an
empty edge list that passes validation and produces a plausible-looking but
wrong artifact. That is the failure shape that makes this worth a belief:
the wrongness is *absence*, so nothing downstream can notice.

Found in the wild: koru/stack's collector read only
`flow.inv().annotations`, which was correct for the `.kz` probes used to
develop it and silently dropped every edge in the `.k` test app — the
manifest emitted three services with zero `depends_on` blocks while the AST
held them all. The fix is the union; `annotation_parser.getCall` accepts the
slice, so iterating both attachment points and deduping is a few lines.

The deeper reading, consistent with [[frag-annotation-entries-are-expressions]]:
annotations are open metadata whose *storage location is a parser-layout
fact*, not part of the convention. The convention is uniform (`depends_on`
means an edge in every context); where a given spelling parks the text is
incidental. So the rule for any AST-walking collector is mechanical: **read
`flow.annotations` and `flow.inv().annotations`, or say which spelling class
you refuse to see.** Build-flag gating has the same hazard — a `[build("x")]`
on the other attachment point gates nothing for you.

Open question deliberately left: whether the AST should normalize to one
canonical slot downstream, or whether the two surfaces are a true semantic
distinction (declaration-level vs invocation-level) that consumers should
keep separate. Today's collectors union them; nobody has shown a consumer
that needs them apart.

Pairs with [[frag-a-vertical-annotation-block-is-scanned-twice]] — that
belief is about how annotation text reaches the AST; this one is about where
it parks once it arrives.
