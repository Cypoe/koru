// PIN (part): diagnostics for errors inside a part file must point INTO the
// part file, not the primary or the merge site. The parse error below lives
// in input.a.k; the refusal must carry input.a.k's location. This is the
// structural contract of the join: parts parse with their OWN path and the
// merge concatenates already-located items — a text-level include (C
// preprocessor style) would flatten every location onto the primary file.
//
// ASPIRATIONAL: `part` is not implemented yet; this test fails until it is.

part a
