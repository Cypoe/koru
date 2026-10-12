// PINS: the KORU161 narrowing wall covers capacity-1 stores — a
// singleton column's declared type resolves from the create's seed block
// (`x: 0.0[f32]`), so a write provably wider than the column is refused
// by the store transform, not left to the host typecheck. On the C lane
// that distinction is semantic: zig would reject the emitted text itself,
// C would round it silently.

import std/io
import std/store

std/store:new(gauge) { x: 0.0[f32] }
std/store:new(src) { big: 0.25[f64] }

std/store:stored { gauge.x: src.big }

std/io:print.ln("done")
