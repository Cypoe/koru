// PINS: `std/grid:for(0..n, g)` refuses to run a range that outruns the
// grid — the check is spelled once before the loop and panics LOUDLY,
// naming the grid. Never clamped, never silently truncated: the range is
// the program's to get right.
import std/io
import std/grid

std/grid:new(cells, size: 8) { v: 0[i64] }

std/io:print.ln("before")
std/grid:for(0..9, cells)
! each i |> std/grid:stored { cells[i].v: i }
std/io:print.ln("unreachable")
