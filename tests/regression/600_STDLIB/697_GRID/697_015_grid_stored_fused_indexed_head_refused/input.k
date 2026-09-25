// PINS: a grid write block whose second field carries an indexed head —
// `cells[0].a: 3.0 cells[0].b: 7.0` — fuses for want of a comma and refuses
// KORU161. Write heads `name[i].field:` are field boundaries the shared
// fused-field detector sees, same as a bare `name:`.
import std/io
import std/grid

std/grid:new(cells, size: 4) { a: 0.0[f64], b: 0.0[f64] }

std/grid:stored { cells[0].a: 3.0 cells[0].b: 7.0 }

std/io:print.ln("x {{ cells[0].a:f }}")
