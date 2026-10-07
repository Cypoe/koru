// A module reached by two doors must still be ONE module.
//
// `orderlib` is a directory module; `orderlib/wid` is a submodule with two
// facets (wid.k contract + wid.kz implementation). The submodule arrives in
// the program twice:
//   - enumerated as a dirent of the directory import (seen_stems merges the
//     facets, but the canonical path used to be whichever dirent readdir
//     surfaced first), and
//   - resolved explicitly by index.kz's own `import orderlib/wid`, which picks
//     the canonical facet by extension priority (.kz wins over .k).
//
// When those two picks disagreed — overlayfs serves pump.k before pump.kz,
// virtiofs the reverse — the dedup walls keyed on canonical path let both
// copies through and every decl emitted twice: the orisha HttpArena Linux
// image failed with 84 duplicate-member errors. The pin is the compile
// itself: a second `orderlib.wid` ModuleDecl makes emission collide.

import std/io
import app/orderlib

app/orderlib:top(): t |> std/io:print.ln("{{ t:s }}")
