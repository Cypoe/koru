// A fold with no `| null` arm refuses: every `?` edge and every `?*Node`
// root reaches the empty case — the base is a law, not a default.
import std/tree

std/tree:node(Node) { item: i64, left: ?Node }

pub tor mk { } -> *Node<owned!>
mk = if(true)
    | then |> std/tree:mint(Node) { item: 1, left: null }: h -> h
    | else -> null

mk(): t
|> std/tree:fold(t, as: i64): c
    | node n -> n.item + n.left
|> std/tree:dispose(t): _
