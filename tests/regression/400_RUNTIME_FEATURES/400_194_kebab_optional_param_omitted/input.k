// PINS: an omitted optional parameter whose declared name is kebab-case
// emits the mangled field name in the null injection — `.pitch_offset =
// null`, not `.pitch-offset = null` (a Zig syntax error). Both call paths
// omit `pitch-offset`: the top-level emitArgs path and the impl-flow raw
// handler-call path — plus an explicit kebab arg as the control.

import std/io
import app/lib/box

tor announce {}
announce = app/lib/box:thing(gain: 1.0): v |> std/io:print.ln("impl {{ v:f }}")

app/lib/box:thing(gain: 2.0): w |> std/io:print.ln("top {{ w:f }}")
app/lib/box:thing(gain: 3.0, pitch-offset: 7.0): x |> std/io:print.ln("expl {{ x:f }}")

announce()
