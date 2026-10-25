// Two `std/tree:node` declarations of one name in one home collide the same
// way two protos do (KORU030).

import std/tree

std/tree:node(Node) { item: i64 }
std/tree:node(Node) { item: i64, left: ?Node }
