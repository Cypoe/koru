// TEST: the accepted residual of `-` as a name glyph
//
// The ruling is uniform: `a-b` is always ONE identifier, `a - b` is always
// subtraction — resolution never depends on scope. This test binds all
// three names: `a-b` resolves to the bound kebab name even though `a` and
// `b` also resolve, and `a - b` subtracts. An author who writes `a-b`
// meaning `a - b` while `a-b` is bound gets the name, silently — that is
// the documented residual ambiguity, and this pin keeps it honest.

import std/io

tor named { a-b: i64, a: i64, b: i64 } -> i64
named -> a-b

tor spaced { a: i64, b: i64 } -> i64
spaced -> a - b

named(a-b: 42, a: 10, b: 3): n |> std/io:print.ln("{{ n:d }}")
spaced(a: 10, b: 3): d |> std/io:print.ln("{{ d:d }}")
