// 695_006 — a `preorder` site nested inside an arm body gets its units.
//
// The coordinator mints each rule/preorder site's qrow/qbody/qsweep units
// from a scan that once saw only top-level `.flow` items; a site nested in
// a continuation tree was invisible to it and the site transform refused
// "unknown store". nestedQSites (store.qsites.kz) mints each nested site as
// the same flow view transform_pass_runner.siteView hands the transform —
// one scan shape for top-level and nested sites. Pinned: preorder inside a
// `for ! each` arm walks DFS — roots first, each node before its children.
import std/io
import std/store
import std/control

std/store:new(world) { n: 0[i64] }
[tree]std/store:new(tree, capacity: 8) { v: i64 }

//   1
//  / \
// 2   3
//      \
//       4
std/store:insert(tree) { v: 1 }
    | row a |> std/store:insert(tree) { v: 2 }
        | row b |> std/store:insert(tree) { v: 3 }
            | row c |> std/store:stored { tree[b].parent: a }
                |> std/store:stored { tree[c].parent: a }
                |> std/store:insert(tree) { v: 4 }
                    | row d |> std/store:stored { tree[d].parent: c }
                        |> std/control:for(0..2)
                            ! each _
                                |> std/store:preorder(tree)
                                    ! preorder { [row]s }
                                        |> std/store:stored { world.n: world.n * 10 + s.v }
                                        |> std/io:print("n {{world.n:d}}\n")
