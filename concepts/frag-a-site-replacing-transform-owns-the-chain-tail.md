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

`preorder` violated this until 695_008 landed the fix: its `rootSite`
carried an empty continuation and ate the tail; it now splits the site's
continuations — named `preorder` arm claimed, branchless tail re-rooted —
the same splice `query` makes. `rule` still carries the empty-continuation
replacement; whether its sites can legally carry a tail is the same
question, now open on `rule`.

`node:new` is the second offender, found by the 115 mirror wall (2026-10-21):
its `rootSite` passed `&.{}` for continuations, so `std/node:new |>` anything
silently never ran — the leak-check failure was the only tell that the drain
tail had been eaten. Same empty-continuation shape as `preorder`, caught by a
mirror that only existed because the wall demanded the transform fire in
module position.

## Family

Sibling of [[frag-a-continuations-owner-is-written-in-its-branch-name]]:
same failure shape — a site consumed more of the caller's chain than it
owned — opposite layer. That belief is about distinguishing template arms
from caller sequel inside a mixed continuation list; this one is about a
transform that never looked at the sequel at all.

## Pin

Regression 695_008 `preorder_keeps_chain_tail`; 115_058
`node_new_in_module` and 115_059 `node_spawn_in_module` pin the tail
through `std/node:new`.
