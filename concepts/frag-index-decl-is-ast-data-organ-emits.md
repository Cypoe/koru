---
type: belief
id: frag-index-decl-is-ast-data-organ-emits
provenance: session 2026-09-16 (Lars + Devin) — std/index design ruling; 690_327 parked red pin
ts: 2026-09-16
tags: [toolchain, store, index, addressing, transforms]
related: [frag-std-store-design, frag-store-cross-store-row-index]
---

# An index is AST-data; the indexed organ emits the machinery

A first-class index is a **declaration, not a runtime structure**: the site
(`std/index:store(players, key)`) is claimed by a `~[norun]` tor — the
kernel:shape pattern — and never executes. It sits in `program.items`
through every transform stage; **the AST is the registry**. The organ being
indexed (`std/store`) discovers the declaration on its ordinary program walk
and emits whatever the index needs: the backing map, and the maintenance
splices inside its own `insert`/`take`/`stored` emit.

Three rulings fell out of the design session:

1. **Maintenance must be emitted by the owning organ.** An index kept by
   interceptor/watch from outside cannot be correct: swap-remove moves a
   row into the deleted slot and *no event fires for the displaced row* —
   the same hole the positional-index interceptor died on (690_STORE
   archaeology). The fixup can only live inside `take`'s own emit.
2. **Store handles, not positions.** The map is key→handle, so the
   moved-row fixup is *unnecessary*, not merely solved: a row's handle is
   unchanged by swap-remove (690_092), and a taken row's entry traps loudly
   via the generational machinery (690_115/116) instead of silently naming
   whoever moved into the slot. `take`'s only index duty is removing the
   taken row's own key — else a lookup on a deleted key traps instead of
   answering `| none`.
3. **The query surface doesn't change.** `! first p when p.<col> == v`
   routes to the map when `<col>` is the declared index column — same
   spelling as the scan, organ decides HOW (the WHAT/HOW split). Only a
   bare equality on the indexed column routes; compound predicates scan.

Open / deliberately unpinned: duplicate-key semantics on insert
(last-wins? refuse? trap? — session lookup wants replace-or-refuse, Lars
to rule), a second index on one store, `stored` writes to the indexed
column (re-key splice), and the routing assertion itself — once the site
is claimed, every behavioral oracle passes via plain sweep, so the pin
needs an emitted-code check (post.sh, convention 690_301) or the dup-key
divergence to distinguish routing from scanning.

The namespace shape is also a ruling: `std/index` is the std root module —
already ambient in every std program — so the index vocabulary arrives
free with any `std/*` import. Suffixes name *organs* (a closed set:
`store`, later `grid`, `kernel`), so exact tors claim them, not a glob —
`std/index:grod` fails unclaimed. The glob road (700_EVENT_GLOBBING,
resurrected same day) stays for genuinely-open families like `log.*`.
