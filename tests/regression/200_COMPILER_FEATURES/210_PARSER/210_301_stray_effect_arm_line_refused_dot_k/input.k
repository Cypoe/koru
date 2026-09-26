// PINS: an effect-arm line (`! name …`) at top level has no construct to
// continue — it is the stray continuation KORU010 names, same as a
// top-level `|` arm. Nothing claims the line, so it must be refused at the
// line as written rather than emitted where the backend has to guess.
import std/io

! whatever b |> std/io:print.ln("x")
