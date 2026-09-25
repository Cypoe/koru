// ASPIRATIONAL — a `[with(...)]` argument names a module this file IMPORTED:
// the annotation abbreviates a declared dependency, it does not create one.
// app/ghost is never imported, so the annotation must refuse with a diagnostic
// that names the module as written — otherwise a flow annotation would quietly
// smuggle file-scope resolution in, which is the import machinery's job.
import std/io

tor start {}
[with(app/ghost)]start = haunt(): h |> std/io:print.ln("{{ h:s }}")

start()
