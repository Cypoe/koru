import std/io
import std/store
import std/grid

std/grid:new(cells, size: 8) { count: 0[i64] }
std/grid:new(twin, size: 8) { w: 0[i64] }
std/grid:pool(ops) { o: 0[i64] }
std/store:new(acc) { n: 0[i64] }

pub tor bump {}
bump = std/grid:stored { cells[2].count: cells[2].count + 1 }

pub tor copy {}
copy = std/grid:for(0..8, cells)
    ! each i |> std/grid:stored { twin[i].w: cells[i].count * 3 }
    | done |> std/io:print.ln("copied {{ twin[2].w:d }}")

pub tor stream {}
stream = std/grid:walk { s: cells.count, 2, d: twin.w, 2 }
    ! each |> std/grid:stored { d[0]: s[0], d[1]: s[1] }
    | tail |> for(0..s.len)
        ! each k |> std/grid:stored { d[k]: s[k] }
    | done |> std/io:print.ln("walked {{ twin[2].w:d }}")

pub tor pooled {}
pooled = std/grid:pool-alloc(ops, size: 4)
    |> std/grid:stored { ops[1].o: 7 }
    |> std/io:print.ln("pool {{ ops[1].o:d }}")
    |> std/grid:pool-free(ops)

pub tor total {}
total = std/grid:sweep(cells)
! sweep c when c.count > 0 |> std/store:stored { acc.n: acc.n + c.count }

pub tor show {}
show = std/io:print.ln("total {{ acc.n:d }}")
