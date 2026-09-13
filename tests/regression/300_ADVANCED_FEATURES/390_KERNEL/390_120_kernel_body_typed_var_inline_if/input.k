// TEST: the JS expression lowering must carry two Zig-spelled Koru forms it
// used to pass through raw:
//
//   - `var name: f64 = …` — a TYPED declaration inside a kernel op body
//     (koru_body mode). Emitted verbatim it reached `node` as
//     `var nx: f64 = 0.0;` — a syntax error, not a wrong answer.
//   - `if (c) a else b` — the inline conditional EXPRESSION, in koru_body
//     (kernel op) AND koru_expr (insert field) modes. The koru_expr path
//     reserved-word-mangled `if`/`else` to `if$`/`else$`.
//
// kind>0.5 rows gain 100, others gain 1; the third row's x is itself an
// inline-if insert field. Both targets print the same three rows.

import std/io
import std/store
import std/kernel

std/store:new(world, capacity: 8) { x: f64, kind: f64 }

std/store:insert(world) { x: 0.0, kind: 0.0 }
std/store:insert(world) { x: 1.0, kind: 1.0 }
std/store:insert(world) { x: (if (1.0 > 0.0) @as(f64, 5.0) else @as(f64, 9.0)), kind: 1.0 }

std/kernel:init(world) {}
| kernel k |> std/kernel:self {
        var bonus: f64 = 0.0;
        bonus = (if (k.kind > 0.5) @as(f64, 100.0) else @as(f64, 1.0));
        k.x += bonus;
    }

std/store:query(world)
! query r |> std/io:print.ln("x {{ r.x:f }}")
