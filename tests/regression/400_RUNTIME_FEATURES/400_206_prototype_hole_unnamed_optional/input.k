// Test 400_206: MUST_RUN — under ~[prototype], a required branch left
//                         unhandled beside unnamed optionals still gets
//                         its @panic hole.
//
// `?maybe` unnamed absorbs silently (355 cluster); it is no answer for a
// required variant, which exists in the emitted union either way. The
// prototype contract is that unhandled required arms become loud holes —
// absence of an arm must not disarm that synthesis.

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
