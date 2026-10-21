// Hello World in pure Koru.
// Was the korulang.org frontpage example until 2026-10-11 — the front page
// now leads with the continuation example, which has no pin yet.
//
// Also pins consumed-transform exclusion: after print.blk runs, the
// program unit must not ship `__printInterpolate` or `@import("ast")`.
// post.sh greps output_emitted.zig.

import std/io

std/io:print.blk {
    {% if debug %}[DEBUG] {% endif %}Hello, {{ name:s }}!
    The answer is {{ count:d }}.
}
