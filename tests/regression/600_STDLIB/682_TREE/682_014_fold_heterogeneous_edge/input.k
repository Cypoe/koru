// A fold over a node whose edge reaches a DIFFERENT node kind refuses —
// v1 folds are single-kind; heterogeneous folds need per-kind arms.
import std/tree

std/tree:node(Leaf) { v: i64 }
std/tree:node(Node) { item: i64, kid: ?Leaf }

pub tor mk { } -> *Node<owned!>
mk = if(true)
    | then |> std/tree:mint(Node) { item: 1, kid: null }: h -> h
    | else -> null

mk(): t
|> std/tree:fold(t, as: i64): c
    | node n -> n.item + 1
    | null -> 0
|> std/tree:dispose(t): _
