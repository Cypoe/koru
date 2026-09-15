// Test: a clamp whose range cannot satisfy the field's bounds refines to
// nothing — `clamp(0,100)` saturates every write into [0,100], so `>200`
// can never hold. The meet is empty and the refusal names the two terms
// that disagree — same KORU205 discipline as `>20000 & <=1000`.
//
// Expected: the compile refuses with "refines to nothing" (EXPECT).
import std/proto
import std/refine

std/proto(Mixer) {
    gain: i64
}

std/refine(Mixer) {
    gain: i64 & clamp(0, 100) & >200
}
