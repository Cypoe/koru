// Test 400_206: MUST_RUN — under ~[prototype], a required branch left
//                         unhandled beside a `|*` residual still gets its
//                         @panic hole.
//
// `|*` routes OPTIONAL branches only (355 cluster); it is no answer for a
// required variant, which exists in the emitted union either way. The
// prototype contract is that unhandled required arms become loud holes —
// a residual's presence must not disarm that synthesis.

[prototype]
import std/io

pub tor draft {}
| done
| later string
| ?maybe string

draft => done

pub tor observe { name: string }
observe = std/io:print.ln(name)

draft()
| done |> observe(name: "BUILT")
|* |> observe(name: "REST")
