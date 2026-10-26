// Mint args must name declared fields — the block is the node's whole shape,
// never a grab-bag (KORU184).

import std/tree

std/tree:node(Node) { item: i64 }

std/tree:mint(Node) { item: 1, bogus: 2 }: _ -> 0
