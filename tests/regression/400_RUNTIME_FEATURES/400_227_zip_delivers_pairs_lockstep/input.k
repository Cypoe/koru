import std/io
import std/control

// `std/control:zip` is a producer over TWO sequence inputs — it walks both in
// lockstep and delivers each aligned pair as a `{ first, second }` record
// through `! each`. A `for` call is one traversal of one iterable (400_226
// pins the axis refusal); zip is a second producer, so lockstep composition
// lives in a declared arm vocabulary, not an adapter object.
//
// The walk stops at the shorter input; `| done n` delivers the pair count —
// the unpaired tail is a number in the terminal arm, not a silent drop.
// `step:` strides the pair index.

std/control:zip(a: 1..4, b: 10..14)
! each { first, second } |> std/io:print.ln("{{ first:d }}+{{ second:d }}")
| done n |> std/io:print.ln("pairs: {{ n:d }}")

std/control:zip(a: &[_]i64{ 1, 2, 3 }, b: &[_]i64{ 10, 20, 30, 40 }, step: 2)
! each { x: first, y: second } |> std/io:print.ln("{{ x:d }}/{{ y:d }}")
| done m |> std/io:print.ln("pairs2: {{ m:d }}")
