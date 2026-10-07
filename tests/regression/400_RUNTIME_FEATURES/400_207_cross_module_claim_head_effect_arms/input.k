// PINS: a CROSS-MODULE claim whose head calls a tor declaring `!` branches.
//
// `lib/hook:closed = lib/cable:dropped(fd) ! gone g |> …` is the claim shape
// orisha's websocket seam uses (`orisha/pump:ws-closed = cable:dropped(fd)`).
// The cross-module impl-override path in visitor_emitter wrote the head call
// in its no-effect form and fed the `!` arm into the result switch:
//
//     const result = lib_cable.dropped_event.handler(.{ .fd = fd });
//     expected 2 argument(s), found 1       …plus a `.gone` switch arm
//                                              naming a variant Output lacks
//
// The module-local twin was fixed at 400_175; the override branch of the same
// emitter never got the partition. A tor with effect branches lowers to
// `handler(input, comptime __H)` — the `!` continuations are handler bodies,
// not Output variants.
import std/io
import app/lib/hook
import app/lib/cable

app/lib/hook:closed = app/lib/cable:dropped(fd)
    ! gone g |> std/io:print.ln("gone {{ g:d }}")
    | ok |> _

app/lib/hook:closed(fd: 9)
