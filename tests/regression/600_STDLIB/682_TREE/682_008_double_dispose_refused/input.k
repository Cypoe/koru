// consume-once: the second dispose is a use-after-consume — the obligation
// checker's wall, not the lane's.

import std/io
import std/tree

std/tree:node(Node) { item: i64 }

std/tree:mint(Node) { item: 1 }: n
|> std/tree:dispose(n): _
|> std/tree:dispose(n): _
|> std/io:print.ln("unreachable")
