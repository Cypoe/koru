// PINS: an effect arm inside a consumer `|>` chain sees enclosing
// prong-payload bindings — they ride the `__HandlersCaps_*` capture
// record, instantiated and assigned at the call site where the binding
// is live. Multiple guarded arms on one branch force the `Handlers_*`
// lowering (no inline splice), whose context-free member fns used to die
// on `'r' not accessible from inner function`. `r` below is `| done r`'s
// payload binding, bound two nesting levels above the synthesized fns.
import std/io

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
| done r |> ticker(n: 3)
    ! tick i when i == 0 |> std/io:print.ln("first {{ r:d }}")
    ! tick i when i == 1 |> std/io:print.ln("second {{ r:d }}")
    ! tick i |> std/io:print.ln("rest {{ i:d }} {{ r:d }}")
