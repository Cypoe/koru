---
type: belief
id: frag-a-wildcard-payload-is-a-payload
provenance: stack-driven emitter defect 2026-10-04 — `| captured c` on
  `capture`'s `| ?captured *` emitted the switch prong without `|c|`,
  leaving `.{ .result = c.v }` referencing an unbound name. Pinned by
  310_136.
ts: 2026-10-04
tags: [koru, branches, payloads, emitter]
---

# `| tag *` is a payload, not an empty payload (belief)

A wildcard branch payload parses to `fields: []`, `is_wildcard: true`.
Predicate sites that count only `fields.len` conclude "no payload" and
suppress the arm's `|b|` capture — but the payload EXISTS (anytype), and
the arm body may reference it. The prong must still destructure it.

`branchHasPayloadFieldsSearchAll` was the lone site that forgot this;
every sibling check (void-payload detection at the three emission sites
that know the rule) already writes `fields.len == 0 and !is_wildcard`.
The fix is the shared predicate: `fields.len > 0 or is_wildcard`.

The generalization worth keeping: "has a payload" is a two-condition
answer — named fields, or the wildcard. Any future site that asks the
question field-count-only reintroduces the same dangling binding.
