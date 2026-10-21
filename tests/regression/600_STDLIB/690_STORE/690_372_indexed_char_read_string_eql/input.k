// 690_372 — a char-column read through `store[h].field` lowers to the
// string slice, so it participates in `==`/`!=` literal compares and
// writes into char columns — at every expression position.
//
// Pins the indexed-read lowering in store.ixrefs.kz: `rows[h].dir` emits
// sliceTo(&(&col.dir)[resolve(h)], 0) — the same shape the qrow
// projection binds — instead of the bare `(&col)[h]` array, which the
// expression rewriter could not parse (`&` inside parens is NoParse in
// ZigExprParser) and Zig refuses to `==`-compare against a literal.
// Covered positions: `if` conditions at a `| row` continuation and
// inside a `! query` arm, a `stored` write value, and an `insert` seed
// field (insert.kz lowers seed values through StoredScan.lowerStoreExprs
// — the same composition the stored RHS gets).
import std/io
import std/store

std/store:new(world) { ph: -1[i64], hits: 0[i64] }
std/store:new(rows, capacity: 8) { dir: char[8], v: i64 }
std/store:new(out, capacity: 4) { dir: char[8] }

std/store:insert(rows) { dir: "ttb", v: 10 }
    | row a |> std/store:insert(rows) { dir: "ltr", v: 20 }
        | row b |> std/store:stored { world.ph: b }
            |> if (rows[world.ph].dir == "ltr")
                | then |> std/store:stored { world.hits: 1 }
            |> std/store:query(rows)
                ! query s
                    |> if (s.dir == "ttb")
                        | then |> std/store:stored { world.hits: world.hits + 10 }
                    |> if (rows[world.ph].dir == "ltr")
                        | then |> std/store:stored { world.hits: world.hits + 100 }
            |> std/store:insert(out) { dir: rows[world.ph].dir }
                | row o |> std/store:stored { out[o].dir: rows[world.ph].dir }
                    |> if (out[o].dir == "ltr")
                        | then |> std/store:stored { world.hits: world.hits + 1000 }
                            |> std/io:print("hits {{world.hits:d}}\n")
