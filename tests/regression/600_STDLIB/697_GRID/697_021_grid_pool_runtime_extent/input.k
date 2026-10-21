// PINS: `std/grid:pool(name) { f: dflt[T] }` — positional storage whose
// extent is decided at runtime by `std/grid:pool-alloc(name, size: <expr>)`
// and released by `std/grid:pool-free(name)`.
//
//   std/grid:pool(ops) { o: 0[u8], j: 0[i64] }
//   std/grid:pool-alloc(ops, size: 5 + 3)
//
// A pool's positions are identities like a grid's — no handles, no
// insert/take — but the extent arrives at alloc, not at `new`. Columns are
// page-backed slices: zero-default columns come from fresh anonymous pages
// (POSIX mmap — zero by OS contract, resident only where written), so a
// pool's declared extent is virtual and its cost is what the program
// touches. `__koru_size` starts 0: reading an unalloc'd pool outruns the
// floor and panics loud.
//
// Reads, writes, `std/grid:for`, and `stored` treat a pool exactly like a
// grid — the same registry finds it, the same cursor proves it; only the
// indexing spelling differs (slice member, no `&` base pin).
//
// Value oracle: ops[0].j=99, ops[5].j=5*2*10=100, ops[7].o=7, ops[4].o=4.

import std/grid
import std/io

std/grid:pool(ops) { o: 0[u8], j: 0[i64] }
std/grid:new(cells, size: 8) { v: 0[i64] }

pub tor seed {}
seed = for(0..8)
    ! each i |> std/grid:stored { cells[i].v: @as(i64, @intCast(i)) * 2 }

pub tor fill {}
fill = std/grid:for(0..8, ops)
    ! each i |> if(i > 1)
        | then |> std/grid:stored { ops[i].o: @intCast(i), ops[i].j: cells[i].v * 10 }

pub tor report {}
report = std/grid:stored { ops[0].j: 99 }
    |> std/io:print.ln("{{ ops[0].j:d }} {{ ops[5].j:d }} {{ ops[7].o:d }} {{ ops[4].o:d }}")
    |> std/grid:pool-free(ops)

std/grid:pool-alloc(ops, size: 5 + 3)
|> seed()
|> fill()
|> report()
