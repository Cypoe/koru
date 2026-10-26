// The invariant-hoist lane interaction: `! each` disallows consuming a
// resource inside the repeating scope (KORU032), so `std/tree:dispose` must
// be recognized as a discharge pre-expansion and the invariant
// mint→sum→dispose prefix lifted onto `| done` — the tree builds once, the
// loop only folds. This pins that the lane's dispose classifies.

import std/io
import std/tree

std/tree:node(Node) { item: i64, left: ?Node, right: ?Node }

pub tor build { item: i64, depth: i64 } -> *Node<owned!>
build = if(depth > 0)
    | then |> build(item: item - 1, depth: depth - 1): l
           |> build(item: item + 1, depth: depth - 1): r
           |> std/tree:mint(Node) { item, left: l, right: r }: h -> h
    | else |> std/tree:mint(Node) { item, left: null, right: null }: h -> h

pub tor sum { t: ?*Node<*> } -> i64
sum = if(t != null)
    | then |> sum(t: t.?.left): l |> sum(t: t.?.right): r -> t.?.item + 1 + l + r
    | else -> 0

capture { acc: 0[i64] }
! as g |> for(0..8)
    ! each _ |> build(item: 0, depth: 4): t
        |> sum(t): c
        |> std/tree:dispose(t): _
        |> captured { acc: g.acc + c }
| captured res |> std/io:print.ln("{{ res.acc:d }}")
