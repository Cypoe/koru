// Single-owner law: an edge arg must be a fresh mint or null. Passing a
// child that is already bound inside another node is a second consume of an
// owned binding — the obligation checker refuses.

import std/io
import std/tree

std/tree:node(Node) { item: i64, left: ?Node }

std/tree:mint(Node) { item: 1 }: inner
|> std/tree:mint(Node) { item: 2, left: inner }: a
|> std/tree:mint(Node) { item: 3, left: inner }: b
|> std/tree:dispose(a): _
|> std/tree:dispose(b): _
|> std/io:print.ln("unreachable")
