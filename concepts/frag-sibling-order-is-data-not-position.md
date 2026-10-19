---
type: belief
id: frag-sibling-order-is-data-not-position
provenance: 2026-10-19 — [tree] preorder walked children by dense position; any order-aware graft (insert between siblings) was inexpressible, and a mid-array take's swap-remove silently reshuffled sibling sequence
ts: 2026-10-19
---

# Sibling order is data, not position

A tree store's dense rows move — swap-remove relocates the last row into a
freed slot, so *physical order is not semantic order*. If traversal order
leans on insertion position, removal reshuffles sibling sequence as a side
effect and "insert between two siblings" has no expression at all.

`preorder(store, order: "col")` makes order explicit data: a numeric column
the sweep sifts by at each level — collect children, insert-sort ascending,
push reversed so the smallest pops first. Stable: ties keep insertion order.
Omitted, the walk keeps the insertion-order default, so ordering is per-site,
not per-store.

The consequences land on the tree itself: mid-sibling grafts become ordinary
data writes (insert a row, write its `ord`), and removal stops carrying an
order side effect — `ord` survives the swap because it rides the row, not the
slot.

## Family

Child of the adjacency-list thesis: tree-ness lives in columns + a walk, not
in allocation or position. `parent` owns structure, `ord` owns sequence —
both are data the handles survive.
