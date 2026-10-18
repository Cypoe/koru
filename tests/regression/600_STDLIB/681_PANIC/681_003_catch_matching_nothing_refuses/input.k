// TEST: std/panic — a catch decl that answers nothing is a refusal, not a
// no-op. The same discipline as testing's unused-mock error: a pillow that
// grafted zero arms is either a stale pattern or a solved problem, and both
// deserve a loud compile, not a silent pass.

import std/io
import std/panic

pub tor safe { n: i64 } -> i64
safe = n * 2

std/panic:catch(safe)
! bad v |> std/io:print.ln("caught {{ v:d }}")

safe(n: 2): v |> std/io:print.ln("{{ v:d }}")
