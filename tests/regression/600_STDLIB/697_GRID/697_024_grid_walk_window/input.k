// PINS: `std/grid:walk { s: inp.b, 2, d: enc.c, 3 }` — a RESLICING window
// walk over borrowed columns. The driver emits
//
//   var s = __koru_grid_inp.b[0..];
//   var d = __koru_grid_enc.c[0..];
//   while (s.len >= 2 and d.len >= 3) {
//       __grid_walkbody_L<line>_event.handler(.{ .s = s, .d = d });
//       s = s[2..];
//       d = d[3..];
//   }
//   __grid_walktail_L<line>_event.handler(.{ .s = s, .d = d });
//
// Each labeled arg names a cursor and the positional after it is its
// stride. The bound is proven once at the loop head (`s.len >= n`) —
// inside, every `s[k]`/`d[k]` is a raw slice access with no per-access
// floor. This is the loop shape LLVM auto-vectorizes: moving base
// pointers plus fixed-offset reads and writes, the same shape Goose's
// slice-window loops emit. The `| tail` arm runs once with the leftover
// window (s.len < n here) — the remainder is the program's to write,
// never silently dropped.
//
// Value oracle: inp = [1..7] u8, stride 2 -> 3 full pairs + 1 leftover;
// enc stride 3: d[0]=s[0]+1, d[1]=s[1]+1, d[2]=s[0]+s[1] per pair;
// tail writes d[0] = s[0] + 100 (the leftover byte, readable).
// enc = [2,3,3, 4,5,7, 6,7,11, 107]; sum = 155.

import std/io
import std/grid

std/grid:new(inp, size: 7) { b: 0[u8] }
std/grid:new(enc, size: 10) { c: 0[u8] }

for(0..7)
! each i |> std/grid:stored { inp[i].b: @as(u8, @intCast(i + 1)) }

std/grid:walk { s: inp.b, 2, d: enc.c, 3 }
! each |> std/grid:stored { d[0]: s[0] + 1, d[1]: s[1] + 1, d[2]: s[0] + s[1] }
| tail |> std/grid:stored { d[0]: s[0] + 100 }
| done |> std/io:print.ln("sum={{ enc[0].c + enc[1].c + enc[2].c + enc[3].c + enc[4].c + enc[5].c + enc[6].c + enc[7].c + enc[8].c + enc[9].c:d }} last={{ enc[9].c:d }}")
