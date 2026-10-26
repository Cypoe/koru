// `build |> fold |> dispose` inside `for ! each` is one invariant prefix:
// fold is hoist-visible by lane contract — it reads a hoisted name and
// returns a value, so the whole prefix lifts before the loop and dispose
// relocates onto | done. Four iterations of a depth-3 tree sum to 60.
import std/io
import std/tree

std/tree:node(Node) { item: i64, left: ?Node, right: ?Node }

pub tor build { item: i64, depth: i64 } -> *Node<owned!>
build = if(depth > 0)
    | then |> build(item: item - 1, depth: depth - 1): l
           |> build(item: item + 1, depth: depth - 1): r
           |> std/tree:mint(Node) { item, left: l, right: r }: h -> h
    | else |> std/tree:mint(Node) { item, left: null, right: null }: h -> h

capture { acc: 0[i64] }
! as g |> for(0..4)
    ! each _ |> build(item: 0, depth: 3): t
        |> std/tree:fold(t, as: i64): c
            | node n -> n.item + 1 + n.left + n.right
            | null -> 0
        |> std/tree:dispose(t): _
        |> captured { acc: @rem(g.acc + c, 4294967296) }
| captured res |> std/io:print.ln("{{ res.acc:d }}")
