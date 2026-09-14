// Test: std/refine's field grammar — `name: type & bound…` lines — meets
// &-atoms per field name, order-independently, against a std/proto
// declaration, and reports the canonical constraint set at Stage C.
// `port` is refined across two lines — the meet must land one interval.
//
// Expected: Stage C prints the canonical meet (expected_comptime); the block
//           self-erases to a `// refine …` marker, runtime prints `refined`.
import std/proto
import std/refine
import std/io

std/proto(Server) {
    port: i64
    retries: i64
    host: string
}

std/refine(Server) {
    port: i64 & >1024
    port: i64 & <=65535
    retries: i64 & >=0 & <10
    host: string
}

std/io:print.ln("refined")
