// 695_008 — a `preorder` site in a `|>` chain keeps the chain tail.
//
// The `! preorder` arm is the site's own; every branchless continuation
// after it is the caller's `|>` sequel and must still run — the same
// site-tail contract query honors (690_366). Pinned: "tail" prints after
// the walk.
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
