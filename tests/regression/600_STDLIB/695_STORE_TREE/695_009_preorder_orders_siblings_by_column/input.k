// 695_009 — `order:` on a preorder site orders each level's children by the
// named numeric column, stable against insertion order on ties. The sibling-
// ordering the [tree] spec deferred (695_001: "explicit z/sibling-order is a
// later thesis") landed as a site clause.
//
//   std/store:preorder(tree, order: "ord")
//
// Roots and each node's children visit ascending by `ord`, not dense
// position. Omitted, the walk stays insertion-ordered (695_001) — `order:`
// is per-site, so a program can hold both walks.
//
// Roots inserted scrambled (ord 3, 1, 2); the first root's children
// scrambled too (ord 2 inserted before ord 1). DFS ordered walk:
//   10 (ord 1) -> children 11 (ord 1), 12 (ord 2) -> 20 (ord 2) -> 30 (ord 3)
// => 10, 11, 12, 20, 30
import std/io
import std/store

[tree]std/store:new(tree, capacity: 64) { val: i64, ord: i64 }

std/store:insert(tree) { val: 30, ord: 3 }
| row r3 |> std/store:insert(tree) { val: 10, ord: 1 }
    | row r1 |> std/store:insert(tree) { val: 20, ord: 2 }
        | row r2 |> std/store:insert(tree) { val: 12, ord: 2 }
            | row c2 |> std/store:insert(tree) { val: 11, ord: 1 }
                | row c1 |> std/store:stored { tree[c2].parent: r1 }
                    |> std/store:stored { tree[c1].parent: r1 }

std/store:preorder(tree, order: "ord")
! preorder e |> std/io:print.ln("{{ e.val:d }}")
