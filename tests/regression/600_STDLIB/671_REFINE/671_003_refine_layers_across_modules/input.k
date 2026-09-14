// Test: constraints layer onto a type declared in ANOTHER module — the
// CUE move of separating declaration from refinement. test_lib/defs.k
// declares `std/proto(Server)` plainly; this entry writes
// `std/refine(app/test_lib/defs:Server)` and the facet meets the
// library's declaration program-wide.
//
// Expected: Stage C prints the canonical meet pinned to the library's
//           home (expected_comptime); runtime prints `layered`.
import app/test_lib/defs
import std/refine
import std/io

std/refine(app/test_lib/defs:Server) {
    port: i64 & >1024 & <=65535
}

std/io:print.ln("layered")
