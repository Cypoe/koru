// PINS: an enclosing-scope binding referenced ONLY inside a store-sweep
// arm body still reaches the member-fn handler. The query graft consumes
// the `! query` subtree into a generated sweepbody unit; the emitted call
// args (`.w = w`) are the only place the name is still spelled, so the
// capture set must be computed from what the arm EMITS — an AST walk of
// the pre-transform subtree misses it and the member fn dies on
// 'use of undeclared identifier w' in emitted Zig.
//
// Surfaced by koru-libs/clay/tests/spec_sel.k: `| win w`'s `w` was used
// only inside a nested preorder row body while `h` survived via a
// surface-level `layout(cl: h)` — the Caps factory minted T_h, not T_w.
//
// Three `! tick` arms force the Handlers_* lowering (no inline splice);
// `w` below is `| done w`'s payload binding, bound outside the fns.
import std/io
import std/store

std/store:new(rows, capacity: 8) { n: 0[i64] }
std/store:insert(rows) { n: 5 }

pub tor query { q: i64 }
! ask i64 -> i64
| done i64

query = ask(q): a => done a

pub tor ticker { n: usize }
! tick usize

proc ticker|zig {
    var i: usize = 0;
    while (i < n) : (i += 1) {
        tick(i);
    }
}

query(q: 41)
! ask v -> v + 1
| done w |> ticker(n: 3)
    ! tick i when i == 0
        |> std/store:query(rows)
            ! query r |> std/io:print.ln("w {{ w:d }} n {{ r.n:d }}")
    ! tick i when i == 1 |> std/io:print.ln("second {{ i:d }}")
    ! tick i |> std/io:print.ln("rest {{ i:d }}")
