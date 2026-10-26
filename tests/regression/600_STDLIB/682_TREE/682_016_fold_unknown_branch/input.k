// An arm the fold does not answer refuses: `| node` and `| null` are the
// whole vocabulary.
import std/tree

std/tree:node(Node) { item: i64, left: ?Node }

pub tor mk { } -> *Node<owned!>
mk = if(true)
    | then |> std/tree:mint(Node) { item: 1, left: null }: h -> h
    | else -> null

mk(): t
|> std/tree:fold(t, as: i64): c
    | node n -> n.item + n.left
    | leaf -> 0
|> std/tree:dispose(t): _
