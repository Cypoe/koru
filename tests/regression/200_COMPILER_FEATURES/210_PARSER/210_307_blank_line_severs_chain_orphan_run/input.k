// PINS: a blank line ends a flow chain — the `|>` steps after it continue
// nothing and refuse as ONE orphan run carrying the run's span and the
// severing rule in its hint, not one error per orphaned line. Session
// telemetry measured stray-continuation refusals arriving in bursts (a dead
// head or a blank orphaning every step below it), so the diagnostic names
// the run and says what separated it from its head.
import std/io

std/io:print.ln("a")

    |> std/io:print.ln("b")
    |> std/io:print.ln("c")
