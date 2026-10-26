// Test: a relational atom — `spend <= balance + margin` — joins the
// `&`-chain like any bound. It meets by union (it relates two fields,
// so no per-field slot can hold it), lands on the typed facet_decl,
// and its joint feasibility is judged over the meet's rows AND the
// per-field bounds together — a bound is a one-term row.
//
// Expected: Stage C prints the canonical meet (expected_comptime);
//           post.sh asserts the explainer spells the same row;
//           runtime prints `refined`.
import std/proto
import std/refine
import std/io
import std/explain

std/proto(Ledger) {
    balance: i64
    margin: i64
    spend: i64
}

std/refine(Ledger) {
    balance: i64 & >=0
    margin: i64 & >=0 & <=100
    spend: i64 & >=0 & spend <= balance + margin
}

std/io:print.ln("refined")
