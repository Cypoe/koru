// A required edge (`left: Node`, no `?`) is never null — optionality is what
// `?` spells (KORU184).

import std/tree

std/tree:node(Node) { item: i64, left: Node }

std/tree:mint(Node) { item: 1, left: null }: _ -> 0
