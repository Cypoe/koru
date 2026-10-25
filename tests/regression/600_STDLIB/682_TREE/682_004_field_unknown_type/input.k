// A field type that is neither payload material (scalar/terminal) nor a
// node-registered edge refuses at declaration (KORU184).

import std/tree

std/tree:node(Node) { item: Nonsense }
