// PIN: spelling the door is refused — `lib/door:default(...)` never reaches
// the door. The `:default` segment is compiler-manufactured: the import
// pipeline rewrites the bare `lib/door(...)` call to it, so writing it is
// redundant surface. KORU208 teaches the bare spelling, at the flow root and
// in continuation position alike.

import lib/door
import lib/wrapped
import std/io

lib/door:default(name: "root"): v1
|> lib/door:default(name: "nested"): v2
|> std/io:print.ln("{{ v1:s }} then {{ v2:s }}")
