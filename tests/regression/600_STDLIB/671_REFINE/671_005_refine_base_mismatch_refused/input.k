// Test: the meet needs one base — refine saying `port: string` against a
// declaration that says `port: i64` is a loud conflict.
//
// Expected: the compile refuses naming the two bases (EXPECT).
import std/proto
import std/refine

std/proto(Server) {
    port: i64
}

std/refine(Server) {
    port: i32 & >0
}
