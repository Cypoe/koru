// std/tree:fold — the catamorphism over an owned tree, pure .k. The node
// arm reads payload fields as payload and EDGE fields as the folded child
// values; `| null` is the empty case. Same checksum as the recursive tor
// (31 over depth 4) — the lane verb is the tor, with the law spelled.
import std/io
import std/tree

std/tree:node(Node) { item: i64, left: ?Node, right: ?Node }

pub tor build { item: i64, depth: i64 } -> *Node<owned!>
build = if(depth > 0)
    | then |> build(item: item - (@as(i64, 1) << @as(u6, @intCast(depth - 1))), depth: depth - 1): l
           |> build(item: item + (@as(i64, 1) << @as(u6, @intCast(depth - 1))), depth: depth - 1): r
           |> std/tree:mint(Node) { item, left: l, right: r }: h -> h
    | else |> std/tree:mint(Node) { item, left: null, right: null }: h -> h

build(item: 0, depth: 4): t
|> std/tree:fold(t, as: i64): c
    | node n -> n.item + 1 + n.left + n.right
    | null -> 0
|> std/tree:dispose(t): _
|> std/io:print.ln("{{ c:d }}")
