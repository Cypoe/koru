// TEST: std/kernel — a store-backed `self` body may be a BLOCK statement
// (if/else), not only `expr;` sequences. The store-mode rewrite used to append
// `;` to any body not ending in one, and `if (…) {…} else {…};` is not legal
// Zig — the pin: the block must pass through unterminated.
//
// kind>0.5 rows gain 100, others gain 1.

import std/io
import std/store
import std/kernel

std/store:new(world, capacity: 8) { x: f64, kind: f64 }

std/store:insert(world) { x: 0.0, kind: 0.0 }
std/store:insert(world) { x: 1.0, kind: 1.0 }

std/kernel:init(world) {}
| kernel k |> std/kernel:self {
        if (k.kind > 0.5) {
            k.x += 100.0;
        } else {
            k.x += 1.0;
        }
    }

std/store:query(world)
! query r |> std/io:print.ln("x {{ r.x:f }}")
