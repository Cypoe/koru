---
type: belief
id: frag-a-runtime-stub-is-a-refusal-deferred
provenance: the cs coverage probe, 2026-10 — 111 cross-module calls to
  |zig-only procs emitted throwing System.Exception stubs and the emit
  verdict stayed green; the same shape intra-module refuses KORU047
ts: 2026-10-09
---

# A runtime stub is a refusal the verdict moved downstream (belief)

When the cs emitter meets a tor whose only bodies are `|zig`, two paths
diverge on module boundaries. Intra-module, `findImplIn` returns null and
emission refuses KORU047 `NoCsProcBody` — the verdict is honest and it
fires at compile time. Cross-module, the emitter instead *writes the
diagnostic into the artifact*: a handler whose body is
`throw new System.Exception("app.lib:classify has no C# implementation
— its body resolves only to a non-cs target")`. Emit reports success,
`dotnet build` succeeds, the apphost runs — and the refusal arrives at
runtime, dressed as a program.

## Why it is worse than a compile refusal, not better

The stub is not leniency; it is a refusal with worse information at a worse
time. The emitter already knows everything the refusal knows — it writes
the exact diagnostic text, including the qualified path and the cause —
but the verdict it returns is *green*. Every consumer of the verdict
(deep-check, the equivalence gate, a coverage probe, a user reading
"compiled") inherits the lie: 111 tests in the 2026-10 probe sat in the
"emitted" bucket while being, functionally, refused.

This is [[frag-a-coverage-hit-needs-an-emission-witness]] one stage
further along the same axis: there, a green verdict couldn't say whether
the text was consumed; here, the emitted artifact *is* present and still
cannot witness the verdict — because the artifact is a rejection note,
not a program. The only honest witness left is execution, and a verdict
that requires running the artifact to discover "no" has deferred the
refusal to the most expensive moment it could fire.

## The rule

A target that cannot produce a body must refuse where it learns the fact —
at emit — not where the fact becomes fatal — at call. If deferral is ever
deliberate (a partially-armed program that wants to run its armed half),
it must be opt-in and visible in the verdict, not the default. A refusal
that reports success manufactures coverage.

## Open

- Whether the intra-module/cross-module split has a reason or is an
  accident of where `findImplIn` fails — the runtime-stub path may exist
  to let *partially* armed programs run; if so, the honest shape is a
  warning in the verdict plus the stub, not silence.
- Whether other emitters (js) carry the same deferred shape.
