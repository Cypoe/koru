// A `| row hN` continuation chain inside a `-> T` tor impl emits on the
// return-switch fast path: each level nests a `return switch` inside the
// previous arm, growing the indent string by 8 per level. That path
// carried a fixed [128]u8 indent buffer; ~14 nested levels overran it
// (index 132 > len 128 — hit by a synthesized component seed). Growable
// emitters now allocate the run; this impl (20 nested continuations)
// crosses the old cliff and must compile and run.

import std/io
import std/store

std/store:new(rows, capacity: 64) { v: i64 }

pub tor seed {}

seed = std/store:insert(rows) { v: 0 }
    | row h0 |> std/store:insert(rows) { v: 1 }
        | row h1 |> std/store:insert(rows) { v: 2 }
            | row h2 |> std/store:insert(rows) { v: 3 }
                | row h3 |> std/store:insert(rows) { v: 4 }
                    | row h4 |> std/store:insert(rows) { v: 5 }
                        | row h5 |> std/store:insert(rows) { v: 6 }
                            | row h6 |> std/store:insert(rows) { v: 7 }
                                | row h7 |> std/store:insert(rows) { v: 8 }
                                    | row h8 |> std/store:insert(rows) { v: 9 }
                                        | row h9 |> std/store:insert(rows) { v: 10 }
                                            | row h10 |> std/store:insert(rows) { v: 11 }
                                                | row h11 |> std/store:insert(rows) { v: 12 }
                                                    | row h12 |> std/store:insert(rows) { v: 13 }
                                                        | row h13 |> std/store:insert(rows) { v: 14 }
                                                            | row h14 |> std/store:insert(rows) { v: 15 }
                                                                | row h15 |> std/store:insert(rows) { v: 16 }
                                                                    | row h16 |> std/store:insert(rows) { v: 17 }
                                                                        | row h17 |> std/store:insert(rows) { v: 18 }
                                                                            | row h18 |> std/store:insert(rows) { v: 19 }
                                                                                | row h19 |> std/store:stored { rows[h19].v: 99 }
                                                                                    |> std/store:stored { rows[h18].v: 98 }

seed()
std/io:print.ln("done")
