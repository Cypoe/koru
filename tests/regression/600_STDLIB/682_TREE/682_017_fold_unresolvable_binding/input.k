// `fold` on a binding whose node kind can't be resolved refuses with the
// same provenance teaching `dispose` gives.
import std/tree

std/tree:node(Node) { item: i64, left: ?Node }

pub tor mk { } -> i64
mk = if(true)
    | then -> 1
    | else -> 0

mk(): t
|> std/tree:fold(t, as: i64): c
    | node n -> n.item + n.left
    | null -> 0
