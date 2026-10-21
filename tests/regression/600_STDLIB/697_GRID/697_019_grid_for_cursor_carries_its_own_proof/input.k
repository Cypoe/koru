// PINS: `std/grid:for(lo..hi, g) ! each i |> ...` — a bounded loop the GRID
// owns, so the index's proof is established once at the door and the body
// rides a trusted cursor.
//
//   std/grid:for(0..8, cells)
//   ! each i |> std/grid:stored { cells[i].v: i * 2 }
//
// The driver emits ONE check before the loop (`lo >= 0`, `hi <= size`,
// `lo <= hi`) and renames the binding to the minted cursor
// `__koru_gi_<grid>_L<line>` — a name that carries WHICH grid the range was
// proven against. Reads AND writes of the proven grid at the bare cursor
// drop the `__koru_at` floor; everything else keeps it.
//
// post.sh pins all four directions in the emitted Zig:
//   cells[i]   read/write  -> __koru_intcast (trusted)
//   cells[i+1] read        -> __koru_at      (not the bare cursor)
//   dst[i]     write       -> __koru_at      (proof was for cells)
//   dst[k]     read        -> __koru_at      (ordinary for, unproven)
//
// The value oracle: cells[i]=2i over 0..8; dst[i]=cells[i]+cells[i+1] over
// 0..7 = [2,6,10,14,18,22,26], dst[7]=0; sum=98.
import std/io
import std/grid

std/grid:new(cells, size: 8) { v: 0[i64] }
std/grid:new(dst, size: 8) { w: 0[i64] }

std/grid:for(0..8, cells)
! each i |> std/grid:stored { cells[i].v: i * 2 }
| done |> std/io:print.ln("written")

std/grid:for(0..7, cells)
! each i |> std/grid:stored { dst[i].w: cells[i].v + cells[i + 1].v }

capture { sum: 0[i64] }
! as s |> for(0..8)
    ! each k |> captured { sum: s.sum + dst[k].w }
| captured r |> std/io:print.ln("{{ r.sum:d }}")
