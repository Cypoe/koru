// Test: cross-kind infeasibility is a loud KORU-layer refusal. The
// bounds `>=5` and `<=0` are one-term rows in the same system as
// `spend <= balance` — `5 <= spend <= balance <= 0` holds nothing,
// and the Fourier-Motzkin leaf names all three witnesses.
//
// Expected: the compile refuses naming the three atoms (EXPECT).
import std/proto
import std/refine

std/proto(L) {
    balance: i64
    spend: i64
}

std/refine(L) {
    balance: i64 & <=0
    spend: i64 & >=5 & spend <= balance
}
