// Property pin: arbitrary bytes never wedge the turn segmenter.
//
// `reslib:fuzz(seed)` deterministically produces either corrupted wire
// (a template with a few positions overwritten) or raw garbage from a
// wire-hostile alphabet. `round` feeds each string to `std/bridge:run`
// and maps EVERY declared outcome to a code — the mapping is total by
// construction (an outcome this file forgot is a compile error, not a
// silent pass), so any reply the segmenter invents breaks the build.
//
// The capture folds the codes into a fingerprint. A run that crashes,
// leaks, or changes which bucket a byte string lands in moves the
// number; N completions proves every item was classified and freed.

import std/io
import std/control
import std/bridge
import std/runtime
import reslib/res
import reslib/fuzz

std/runtime:register(scope: "res") {
    reslib.res:mint -> mint(1)
    reslib.res:grab -> grab(1)
    reslib.res:release -> release(1)
}

tor round { br: *std/bridge:Bridge<session>, seed: usize } -> i64
round = reslib/fuzz:fuzz(seed) : src |> std/bridge:run(br, source: src)
    | result _ |> reslib/fuzz:code(c: 0) : v -> v
    | defined _ |> reslib/fuzz:code(c: 1) : v -> v
    | residue _ |> reslib/fuzz:code(c: 2) : v -> v
    | partial _ |> reslib/fuzz:code(c: 3) : v -> v
    | unhandled-branch _ |> reslib/fuzz:code(c: 4) : v -> v
    | exhausted _ |> reslib/fuzz:code(c: 5) : v -> v
    | parse-error _ |> reslib/fuzz:code(c: 6) : v -> v
    | validation-error _ |> reslib/fuzz:code(c: 7) : v -> v
    | shape-error _ |> reslib/fuzz:code(c: 8) : v -> v
    | event-denied _ |> reslib/fuzz:code(c: 9) : v -> v
    | dispatch-error _ |> reslib/fuzz:code(c: 10) : v -> v
    | scope-not-found _ |> reslib/fuzz:code(c: 11) : v -> v

[with]std/bridge:create(id: "fz", scope: "res"): br
|> capture { sum: @as(i64, 0), count: @as(i64, 0) }
! as acc |> for(0..200)
    ! each i |> round(br, seed: i)
        | ok code |> captured { sum: acc.sum + code, count: acc.count + 1 }
| captured final |> std/io:print.ln("200 rounds: fingerprint {{ final.sum:d }} over {{ final.count:d }}") |> std/bridge:close(br)
