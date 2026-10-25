// std/tree: a node declaration registers kind=node in the shared registry,
// mint creates owned nodes with `?`-edge slots, dispose consumes the root
// and frees recursively. The checksum exercises: payload fields, optional
// self-edges, a recursive borrow traversal, and the mint→borrow→consume arc.

import std/io
import std/tree

std/tree:node(Node) { item: i64, left: ?Node, right: ?Node }

pub tor build { item: i64, depth: i64 } -> *Node<owned!>
build = if(depth > 0)
    | then |> build(item: item - (@as(i64, 1) << @as(u6, @intCast(depth - 1))), depth: depth - 1): l
           |> build(item: item + (@as(i64, 1) << @as(u6, @intCast(depth - 1))), depth: depth - 1): r
           |> std/tree:mint(Node) { item, left: l, right: r }: h -> h
    | else |> std/tree:mint(Node) { item, left: null, right: null }: h -> h

pub tor sum { t: ?*Node<*> } -> i64
sum = if(t != null)
    | then |> sum(t: t.?.left): l |> sum(t: t.?.right): r -> t.?.item + 1 + l + r
    | else -> 0

build(item: 0, depth: 4): t
|> sum(t): c
|> std/tree:dispose(t): _
|> std/io:print.ln("{{ c:d }}")
