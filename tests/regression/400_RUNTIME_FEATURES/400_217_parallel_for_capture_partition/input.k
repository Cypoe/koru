// Pins: a [parallel] for whose effect arm writes a captured cell lowers to
// chunk-private partials + a field-wise additive combine at join — the
// checksum must be the serial fold's answer, not a torn or doubled one.
import std/io

capture { acc: 0[i64] }
! as a |> [parallel]for(1..1001)
    ! each i |> captured { acc: a.acc + @as(i64, @intCast(i)) }
| captured r |> std/io:print.ln("{{ r.acc:d }}")
