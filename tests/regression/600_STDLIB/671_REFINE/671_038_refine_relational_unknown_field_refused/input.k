// Test: a relational atom's variables are field names — each must
// exist on the proto declaration and resolve to an integer scalar.
// `nosuch` declares nothing, so the row refines nothing.
//
// Expected: the compile refuses naming the missing field (EXPECT).
import std/proto
import std/refine

std/proto(L) {
    spend: i64
    balance: i64
}

std/refine(L) {
    spend: i64 & spend <= balance + nosuch
}
