---
type: belief
id: frag-a-site-replacing-transform-owns-the-chain-tail
provenance: 2026-10-19 — gallery_comp moved spec expansion to preorder; the whole post-sweep tail of the frame arm (emit, drivers, quit) vanished from emitted code
ts: 2026-10-19
---

# A site-replacing transform owns the chain tail — drop nothing after the site

When a comptime transform rewrites its invocation site into a replacement
flow, the site's continuation — every `|>` sibling the caller wrote *after*
the transform's own arms — still belongs to the caller. The replacement must
re-root that tail under itself (the same splice `query` makes: "the tail
rides as the replacement's continuation children").

A replacement that returns an empty continuation silently discards the rest
of the author's program — the worst possible failure shape, because it
compiles clean and simply never runs.

`preorder` does exactly this today (695_008, red): its `rootSite` carries no
continuations, so a `preorder` mid-chain eats everything after its arm. The
contract the fix should honor is the query one — the same site shape, the
same splice. `rule` shares the empty-continuation replacement; whether its
sites can legally carry a tail is the same question.

## Family

Sibling of [[frag-a-continuations-owner-is-written-in-its-branch-name]]:
same failure shape — a site consumed more of the caller's chain than it
owned — opposite layer. That belief is about distinguishing template arms
from caller sequel inside a mixed continuation list; this one is about a
transform that never looked at the sequel at all.

## Pin

Regression 695_008 `preorder_drops_chain_tail`.
