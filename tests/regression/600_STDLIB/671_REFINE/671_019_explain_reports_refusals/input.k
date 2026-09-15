// Test: `koruc explain` on a program that REFUSES — explain runs instead
// of the pipeline, so the explainer folds the same meet on a broken
// program and reports each refusal with its reason: an orphaned anchor,
// a bound on a non-integer terminal. The compile still refuses KORU205.
import std/proto
import std/refine
import std/explain

std/proto:string(Email)

std/refine(Ghost) {
    port: i64 & >1024
}

std/proto(Contact) {
    email: Email
}

std/refine(Contact) {
    email: Email & >5
}
