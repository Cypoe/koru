// Test: refine must meet a real field — a name the declaration never
// declared is a loud refusal, not a silently-new field.
//
// Expected: the compile refuses naming 'sock' (EXPECT).
import std/proto
import std/refine

std/proto(Server) {
    port: i64
}

std/refine(Server) {
    port: i64 & >1024
    sock: i64 & >0
}
