---
type: belief
id: frag-a-destructure-is-a-schema
provenance: std/json:parse transform + yyjson/bench/bench.k measurement, 2026-10-08
ts: 2026-10-08
---

# A destructure is a schema (belief)

A program that consumes structured input already writes its schema once:
the destructure that names the fields. Making the author write it a second
time — a DOM navigation chain, a validator spec, a format string — is a
redundancy that costs twice: once in the author's keystrokes and once at
runtime, because the re-spelled schema erases the shape information that
would have made the parse cheap.

`std/json:parse` reads the `ok` branch's destructure at comptime and emits
a bespoke recursive-descent parser for exactly that shape — per-key
dispatch, typed readers per field, a generic value-skipper for undeclared
keys. No `Doc`, no `root()`, no `object.get`, no `as.*` chain: the payload
arrives as typed bindings in the branch. The same license `std/regex:match`
takes with named groups — the destructure names the payload.

## What the instrument said

`koru-libs/yyjson/bench/bench.k`: one 250-byte document, identical field
reads, `std/benchmarking:run` 3s windows, checksum-verified arms.

- Debug: 918,126 vs 497,411 passes — ~1.85x.
- ReleaseFast, three runs: 10.98M / 10.60M / 10.90M vs 437K / 491K / 507K
  — ~22x at the floor.

The asymmetry between build modes is the finding, more than the ratio:
yyjson's arm barely moved Debug→ReleaseFast (its cost is FFI hops plus a
prebuilt C library — nothing to optimize), while the generated parser went
~12x the moment an optimizer saw it. One arm was already as fast as its
architecture permits; the other was barely started. "The DOM was the cost"
is a measurement, not a slogan.

## The trade it names

Field values are arena-scoped to the `ok` branch's chain — a scoped borrow,
not a caller-owned value. Anything that must outlive the branch needs an
owning document, which is what `koru/yyjson` exists for: unknown shape,
held, mutated, re-serialized — DOM work. The two surfaces divide JSON by
lifetime, not by speed.

## The generalization

This is not a JSON trick. Any input whose shape a program can name at
comptime — wire envelopes, config blocks, HTTP headers, protocol frames —
gets a bespoke parser instead of a navigation walk. `std/regex` and
`std/parser` established that comptime shape → specialized code is the
house pattern; `std/json:parse` is the datum that the *consumer's own
syntax* can carry the shape.

## Open questions

- Emit is unbuilt: the write side (`std/json:emit`) is the symmetric win —
  a destructure-driven emitter writes straight to the buffer with no tree
  allocation, and wire-protocol traffic is half emit.
- Escaping the scope boundary: `string<allocated!>`-style fields that own
  their copy are not spellable in a destructure today; if they become so,
  the scoped-borrow line moves.
- Escaped JSON keys never match a destructure identifier (keys compare
  raw) — known cut, pinned for a later pass.
- Bench breadth: one 250B envelope measured; array-heavy and deep-nested
  docs are unmeasured, and simdjson-class multi-KB throughput is a
  different regime this does not claim.
