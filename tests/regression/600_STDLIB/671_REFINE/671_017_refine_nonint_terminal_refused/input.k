// Test: bounds on a terminal that resolves to a non-integer scalar refuse —
// `email: Email` where Email minted by `std/proto:string(Email)` cannot take
// `& >5`. The terminal resolves to []const u8 and legality judges THAT, not
// the name — the refusal names the field's spelled base.
//
// Expected: the compile refuses with "integer scalars only" (EXPECT).
import std/proto
import std/refine

std/proto:string(Email)

std/proto(Contact) {
    email: Email
}

std/refine(Contact) {
    email: Email & >5
}
