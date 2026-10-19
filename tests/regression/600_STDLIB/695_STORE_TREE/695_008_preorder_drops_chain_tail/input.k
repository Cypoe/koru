// 695_008 — a `preorder` site in a `|>` chain does not eat the chain tail.
//
// `preorder`'s transform replaces its site with
// `rootSite(sweep_inv, &[_]ast.Continuation{})` — an EMPTY continuation
// (store.preorder.kz). `query` splices the same site shape but re-roots the
// tail under the replacement ("the tail rides as the replacement's
// continuation children", store.query.kz). The sibling `|>` step after the
// `! preorder` arm is part of the same chain and must still run — pinned:
// "tail" prints after the walk.
import std/io
import std/store

[tree]std/store:new(tree, capacity: 8) { v: i64 }

//   1
//  /
// 2
std/store:insert(tree) { v: 1 }
    | row a |> std/store:insert(tree) { v: 2 }
        | row b |> std/store:stored { tree[b].parent: a }
            |> std/store:preorder(tree)
                ! preorder { [row]s } |> std/io:print.ln("n {{ s.v:d }}")
            |> std/io:print.ln("tail")
