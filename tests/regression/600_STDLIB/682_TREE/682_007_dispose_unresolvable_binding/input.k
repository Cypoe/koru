// dispose must resolve the binding's node kind — a binding that never
// carried `*X<...>` for a registered node refuses (KORU184), never
// silently free()s the wrong shape.

import std/tree
import std/io

std/tree:node(Node) { item: i64 }

std/io:read.ln(): l |> std/tree:dispose(l): _ |> std/io:print.ln("x")
