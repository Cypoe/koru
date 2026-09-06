// PIN (part): `part impl` in the entry loads every `input.impl.k*` sibling —
// the same join the stem-facet mechanism makes, but NAMED by the declaration
// instead of derived from the directory. Events declared in a part are in
// scope for the primary's flows, referenced unqualified — the merge puts
// primary and parts in one module (the 140_009 facet contract, through part).
//
// ASPIRATIONAL: `part` is not implemented yet; this test fails until it is.

part impl

compute(x: 42): r |> show(v: r)
