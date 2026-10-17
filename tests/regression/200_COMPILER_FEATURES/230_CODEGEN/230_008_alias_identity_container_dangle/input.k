// Test: a module's emitted container identity is a property of the module,
// not of the import-path spelling the consumer used.
//
// `a` and `b` are two aliases for the same test_lib directory. The consumer
// imports `a/pump` — so the module's container materializes as `koru_a`.
// But pump's own decl spells its payload type `b/pump:Payload`, and the
// `?`-optional-arm noop the emitter synthesizes writes
// `koru_b.koru_pump.Payload` — a container that does not exist. One module,
// two aliases, two emitted names; the reference dangles.
//
// Surfaced by koru-libs/metal/tests/drift.k: `libs/metal` (consumer alias)
// vs `koru/metal:KeyData` (decl's own canonical spelling via the builtin
// `koru` alias) — `koru_koru.koru_metal` never materializes under a
// `libs/metal` import.
//
// Expected once fixed: done.

import std/io
import a/pump

a/pump:pump(n: 3)
! bump i -> i
| done |> std/io:print.ln("done")
