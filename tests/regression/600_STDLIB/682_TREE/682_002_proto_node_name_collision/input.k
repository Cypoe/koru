// A name registers once per home, whatever its kind — a proto terminal and a
// tree node sharing `Port` collide at declaration (KORU030).

import std/proto
import std/tree

std/proto:i64(Port)
std/tree:node(Port) { item: i64 }
