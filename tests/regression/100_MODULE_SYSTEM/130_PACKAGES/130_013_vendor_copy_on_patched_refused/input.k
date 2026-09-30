// Pins that `vendor copy` on a patched tree is refuse: copy would overwrite
// as-copied, which is the record of what upstream sent. `sync` is the command
// that accepts a patch (130_010). The program still compiles — live matches
// as-compiled. post.sh is the copy refusal.

import std/io
import std/vendor

std/vendor:bindings {
    koru/vaxis: ./vendored/vaxis
}

import koru/vaxis

koru/vaxis:greet(): v |> std/io:print.ln("{{ v:s }}")
