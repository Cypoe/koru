---
type: belief
id: frag-a-tree-node-is-a-kind-tagged-registry-entry
provenance: std/tree design session (pointed-salt) + implementation — Lars ruled the lane is a kind-tagged shared-registry entry, not a store axis or host-struct door
ts: 2026-10
tags: [koru, tree, proto, registry, obligations, design-ruling]
---

# A tree node is a kind-tagged entry in the shared proto registry

`std/tree:node(Name)` declares a heap-node KIND, not a value. It registers
`Name` in the same registry `std/proto` and `std/foreign` share — one name
per home, whatever the kind; a proto↔node same-name pair collides at
declaration (KORU030).

What decides a field's role is the registry KIND of its type: scalars and
terminal/compound protos are payload (embedded); node-registered names are
edges (pointers, recursive and cyclic-capable by construction — the self
edge is the normal case). Optionality is spelled on the type
(`left: ?Node`), matching tor-parameter grammar. A proto field that names a
node refuses with teaching — edges point, payloads embed.

Ownership is the edge: mint's edge params are `<!owned>`-consuming, so the
single-owner law is the obligation checker, not a lint — reparenting a
bound child is a second consume (use-after-discharge), double dispose is
the same wall, and a `?`-edge accepts a fresh mint or `null`. `dispose`
consumes the root and recurses over edge fields.

The transform expands in the backend; the invariant-prefix hoist runs in
the frontend BEFORE expansion — so the pass must see `std/tree:dispose` as
a consume by lane contract (qualifier+verb, arg value is the discharged
root), or the hoisted producer's obligation registers outer-scope and the
in-loop consume refuses KORU032. Ordering is load-bearing: any future
owned-lane verb that discharges inside `! each` needs the same visibility.

Deferred by design, refused loudly not silently: proto-compound payload
embeds, `walk`/`fold` traversal verbs, JS/CS materialization, shared edges
(graph semantics want refcounting — a future `std/graph` kind).
