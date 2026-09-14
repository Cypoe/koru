// Test: std/refine's field grammar — `name: type & bound…` lines — meets
// &-atoms per field name, order-independently, and reports the canonical
// constraint set at Stage C. Importing the module IS the vocabulary: the
// block resolves only because `std/refine` was imported here.
//
// Structure:
//   std/refine(Server) { … } declares an entry whose fields carry bounds;
//   `port` is refined across two lines — the meet must land one interval.
//
// Expected: Stage C prints the canonical meet (expected_comptime); the block
//           self-erases to a `// refine …` marker, runtime prints `refined`.
import std/refine
import std/io

std/refine(Server) {
    port: int & >1024
    port: int & <=65535
    retries: int & >=0 & <10
    host: string
}

std/io:print.ln("refined")
