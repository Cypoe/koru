// Test: an armed kebab-named optional branch (`! ?key-down`) FIRES.
//
// Optional arms bind through a comptime presence test —
// `if (@hasDecl(__H, "<arm>")) __H.<arm> else noop` — while the Handlers
// decl itself is minted kebab→snake (`key_down`). The presence key must
// carry the same mangled name; a raw-spelling key never matches and the
// armed handler is silently replaced by the producer-side noop.
//
// The resume-valued `! tick` arm is what lowers this invocation to the
// Handlers_N path (a plain optional-arm-only call splices inline, where
// the bug cannot surface).
//
// Surfaced by koru-libs/metal: `! ?key-down` / `! ?mouse-down` reached
// the ObjC IMP and the mailbox, then died on the noop alias.

import std/io
import std/store
import lib/pump

std/store:new(s) { v: 0[i64] }

tor produce {}
| ok i64
| err string
proc produce|zig { return .{ .ok = 3 }; }

produce()
| ok n |> lib/pump:pump(n)
    ! tick i |> std/store:stored { s.v: s.v + i } -> i
    ! key-down k |> std/io:print.ln("hit {{ k:d }}")
    | done |> std/io:print.ln("v {{ s.v:d }}")
| err e |> std/io:print.ln("err {{ e:s }}")
