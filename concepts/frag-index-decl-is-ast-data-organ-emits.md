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
(`std/indexes:store(players, key)`) is claimed by a `~[norun]` tor — the
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

Shipped resolutions (690_327 green): **lowest-dense-holder wins** on
duplicate keys — the map holds the lowest live row per key, so `! first`
keeps scan parity; insert `getOrPut`-keeps, take releases only if the taken
row held the entry then rescans for the next-lowest duplicate, and `stored`
writes to the indexed column release the old key and claim the new only when
the written row becomes the lowest holder. The routing assertion is a
`post.sh` emitted-code check (the map is consulted in `! first`), since
every behavioral oracle also passes via plain sweep. Both backends emit
the machinery — `AutoHashMapUnmanaged(key, i64)` in Zig, `Map` in JS —
and index-only stores run teardown (map deinit/clear) even with no owned
columns; the Debug leak checker pins that.

Still unpinned: a second index on one store, indexed fixed-char and owned
columns (loud refusal today — "a later rung"), and take-side rescan cost
on heavy duplicate load.

The namespace shape is also a ruling, and it drifted at ship time: the
vocabulary lives in `std/indexes` (plural), not `std/index` — `index.kz`
*is* the std root module, so a same-named declaration file collides
(KORU200). Suffixes still name *organs* (a closed set: `store`, later
`grid`, `kernel`), claimed by exact tors, not a glob —
`std/indexes:grod` fails unclaimed. The glob road (700_EVENT_GLOBBING,
resurrected same day) stays for genuinely-open families like `log.*`.
