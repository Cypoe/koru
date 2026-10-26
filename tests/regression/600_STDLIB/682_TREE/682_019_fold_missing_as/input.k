// `fold(t)` without `as:` refuses — the synthesized tor needs a concrete
// return type and .k has no inference to recover it from the arms.
import std/tree

std/tree:node(Node) { item: i64, left: ?Node }

pub tor mk { } -> *Node<owned!>
mk = if(true)
    | then |> std/tree:mint(Node) { item: 1, left: null }: h -> h
    | else -> null

mk(): t
|> std/tree:fold(t): c
    | node n -> n.item + n.left
    | null -> 0
|> std/tree:dispose(t): _
