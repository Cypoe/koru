// A step chain inside a fold arm refuses — v1 arms are single `-> expr`
// terminals; spell the work as a tor and call it.
import std/tree

std/tree:node(Node) { item: i64, left: ?Node }

pub tor double { x: i64 } -> i64
double = if(true)
    | then -> x * 2
    | else -> 0

pub tor mk { } -> *Node<owned!>
mk = if(true)
    | then |> std/tree:mint(Node) { item: 1, left: null }: h -> h
    | else -> null

mk(): t
|> std/tree:fold(t, as: i64): c
    | node n |> double(x: n.item): d -> d + n.left
    | null -> 0
|> std/tree:dispose(t): _
