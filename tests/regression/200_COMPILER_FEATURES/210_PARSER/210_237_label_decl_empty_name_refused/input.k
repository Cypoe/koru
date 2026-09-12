// PINS: a label declaration with no name is malformed. The `~@`/`@` prefix
// dispatch guaranteed the marker, so the existing "malformed label
// declaration" guard could never fire — and the empty name sailed through to
// a compiled program (measured: `@` alone compiled cleanly before this pin).
import std/compiler


tor pick { x: i32 }
| ok i32
| bad

@
