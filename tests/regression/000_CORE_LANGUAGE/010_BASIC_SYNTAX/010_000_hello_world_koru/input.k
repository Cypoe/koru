// Hello World in pure Koru.
// This is the frontpage example from korulang.org.
//
// Also pins consumed-transform exclusion: after print.blk runs, the
// program unit must not ship `__printInterpolate` or `@import("ast")`.
// post.sh greps output_emitted.zig.

import std/io

std/io:print.blk {
    {% if debug %}[DEBUG] {% endif %}Hello, {{ name:s }}!
    The answer is {{ count:d }}.
}
