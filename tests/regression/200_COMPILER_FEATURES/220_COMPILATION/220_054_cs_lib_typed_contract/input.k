// 220_054: the cs lib surface is TYPED, not dynamic — a record-payload
// branch emits a generated payload struct (`<branch>_payload` nested in
// the event class) so a cross-assembly consumer that reads a member the
// payload does not declare fails at C# COMPILE time (CS1061), not as a
// RuntimeBinderException from the DLR. `handler`'s envelope already
// carried Input/Output; this pins the same contract one level inward.
import std/io

pub tor probe {}
| hit { x: i64, y: i64 }
| miss

pub tor answer {} -> i64

probe => hit { x: 40, y: 2 }
answer -> 42

probe()
| hit h |> std/io:print.ln("{{ h.x + h.y:d }}")
| miss |> std/io:print.ln("miss")
