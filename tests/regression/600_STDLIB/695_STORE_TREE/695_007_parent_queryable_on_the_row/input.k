// 695_007 — the [tree]-synthesized `parent` is a projected row field.
//
// TT0 (DESIGN.md): `entity.parent` is queryable so traversal can follow it.
// TT1 keeps it off the INSERT surface — inserts never name it — but a row
// binding's column set is the insert surface plus `parent`. The derivation
// once read only the insert event's inputs, so `s.parent` on a `! query`
// arm refused as an unknown field while `tree[h].parent` indexed fine.
// Pinned: `when s.parent == -1` selects the root, `tree[s.parent].v`
// follows the edge, and `!= -1` selects the children.
import std/io
import std/store

std/store:new(world) { roots: 0[i64], pv: 0[i64] }
[tree]std/store:new(tree, capacity: 8) { v: i64 }

std/store:insert(tree) { v: 1 }
    | row a |> std/store:insert(tree) { v: 2 }
        | row b |> std/store:insert(tree) { v: 3 }
            | row c |> std/store:stored { tree[b].parent: a }
                |> std/store:stored { tree[c].parent: a }
                |> std/store:query(tree)
                    ! query { [row]s } when s.parent == -1
                        |> std/store:stored { world.roots: world.roots + 1 }
                        |> std/store:query(tree)
                            ! query { [row]t } when t.parent != -1
                                |> std/store:stored { world.pv: world.pv + tree[t.parent].v }
                                |> std/io:print("r {{world.roots:d}} pv {{world.pv:d}}\n")
