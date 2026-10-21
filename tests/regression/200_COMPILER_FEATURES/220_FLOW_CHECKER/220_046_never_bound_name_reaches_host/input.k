// PINS: a name bound NOWHERE in the flow is not KORU108's case — that check
// refuses a name bound somewhere but referenced off its path (400_213,
// 400_214), and `zzz` has no bind site to name. So today the refusal is the
// host's `use of undeclared identifier 'zzz'` from the emitted Zig.
//
// The bare BACKEND_COMPILE_ERROR marker is the tripwire: the harness passes
// it only while backend.err carries no `error[KORU…]` — if koruc ever gains
// a full unresolvable-name refusal, this test goes red until the diagnostic
// is pinned here.
import std/io

pub tor show { v: i64 }

show = std/io:print.ln("v {{ v:d }}")

std/io:print.ln("start") |> show(v: zzz)
