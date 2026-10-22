// TEST: a DECLARED kebab member field is legal — the ruling's affirmative leg
//
// `p.x-c` where `x-c` IS a declared field of `p`'s record is a legal member
// access: `-` joins identifiers everywhere, member names included. KORU182
// (230_029) stays silent because `x-c` is in the field set, and the emitter
// mangles it to `p.x_c` alongside the record literal's `.{ .x_c = 10 }`.
// Pair: 230_029 pins the trap (`x-c` not a field → diagnostic); this pins
// the working program the trap must never refuse.

import std/io

tor mk { } -> { x-c: i64, y: i64 }
mk -> { x-c: 10, y: 3 }

tor use { p: { x-c: i64, y: i64 } } -> i64
use -> p.x-c

mk(): p |> use(p): r |> std/io:print.ln("{{ r:d }}")
