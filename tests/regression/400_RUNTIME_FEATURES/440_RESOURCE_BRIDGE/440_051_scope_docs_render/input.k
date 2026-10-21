// Pins: declaration prose in a vertical annotation block on a collected
// tor renders through the surface — scope-vocabulary shows each verb's
// first doc line after ` — `, and scope-manifest ships the whole doc in
// its JSON `doc` field. An undocumented verb renders with no suffix.
import std/io
import std/runtime
import doclib/res

std/runtime:register(scope: "docs") {
    doclib.res:mint -> mint(1)
    doclib.res:grab -> grab(1)
    doclib.res:release -> release(1)
}

std/runtime:scope-vocabulary(name: "docs")
| ok v |> std/io:print.ln("{{ v:s }}")
| not-found |> std/io:print.ln("FAIL: scope docs not found")

std/runtime:scope-manifest(name: "docs")
| ok m |> std/io:print.ln("{{ m:s }}")
| not-found |> std/io:print.ln("FAIL: manifest not found")
