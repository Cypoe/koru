// An empty source block transported to a comptime handler must emit a
// valid empty Source — `.text = ""` — not a dangling `.text =` splice.
//
// The defect this pins: the Source-arg emitter writes captured text as
// `\\` multiline-string lines, one per source line — and an empty capture
// has zero lines, so it emitted `.text =` with nothing after it. Emitted
// Zig failed to compile (`expected expression, found ','`). Only
// reachable once 210_311/210_312's parser fix let empty source exist at
// all; found by koru/stack's `service(...) {\n}` empty body.

import std/io

[comptime|norun]pub tor sink {
    source: Source,
}

proc sink|zig {
}

sink {
}

pub tor run {}
run = std/io:print.blk {
    survived
}
run()
