// A bare `n` in the node arm refuses — the fold arm reads the node's
// fields (`n.<field>`); it can't hold the node itself.
import std/tree

std/tree:node(Node) { item: i64, left: ?Node }

pub tor mk { } -> *Node<owned!>
mk = if(true)
    | then |> std/tree:mint(Node) { item: 1, left: null }: h -> h
    | else -> null

mk(): t
|> std/tree:fold(t, as: i64): c
    | node n -> n
    | null -> 0
|> std/tree:dispose(t): _
