// A second module arming a query on sim's `items` store. Its `! query` arm
// sits on line 14 — the same source line as sim/index.k's arm — so the
// synthesized sweep names must carry the arming file's identity, not only
// store+line.
import std/io
import std/store
import sim

// No store here — the `items` backing lives in sim's module struct.
//
// The arm below sits on line 14 — sim/index.k's arm sits on line 14 too.
pub tor dump-ext { }
dump-ext = std/store:query(items)
    ! query e |> std/io:print.ln("ext {{ e.v:d }}")
