---
type: belief
id: frag-mojo-linearity-is-a-mortality-law-not-an-obligation-algebra
provenance: measured 2026-09-16 by compiling 9 cases of tests/regression/900_EXAMPLES_SHOWCASE/910_LANGUAGE_SHOOTOUT/2104_* under Mojo 1.2.0.dev2026091605 (mojo-comparison/, verdicts carry verbatim compiler output), after reading CheckLifetimes.cpp and the stdlib's Deinitable machinery in the ~/src/modular oracle at 64fcd68
ts: 2026-09-16
---

# Mojo's linearity is a mortality law, not an obligation algebra (belief)

Mojo does not have a linear type system in the type-theory sense, and the
difference is not pedantry — it predicts exactly which rows of the shootout it
wins and which it cannot reach.

**Linearity is defined negatively.** A type is linear iff it does not conform
to `Deinitable` — spelled `Deinitable where False`. There is no linear flag,
no linear arrow, no use-count checker. There is a universal mortality law —
every value must die, last-use ASAP, tracked by per-field `consumedValues`
bitvectors in a ~5.7k-line MLIR pass — and "linear" is the name for the types
the law cannot kill itself. Multiple named `deinit self` methods give
commit-XOR-rollback natively; `where Self.<param>` on the method gates it to a
phantom state, which is `<!active>`-demands minus the accounting.

**The mandate survives scope.** The debt rides the type, not the frame:
return the value and the caller inherits the check; the contract travels in
signatures, checked per-function on parametric IR. `_ = x` does not launder
it — the discard site is itself the error, the direct opposite of Rust's
`let _ =` suppressing `#[must_use]` under `deny`. Measured: all five rows
Rust loses (`2104_01`, `02`, `20`, `21`, `22`) are compile refusals in Mojo
with zero hand-written guards.

**What the law cannot express is everything above the death.** Mojo knows a
value must die; it cannot know *what dying means*. There is no obligation
that outlives a consume — `use(owned tx) -> Tx` (consume-and-reissue) and
`shut(owned tx)` (consume-and-release) are the same shape to the checker, so
the re-issuer-is-not-a-discharger bug `440_007` pins is not prevented in
Mojo, it is *unstatable*: the compiler never selects among dischargers, so
there is nothing to select wrongly. The discharger list in its diagnostic is
author-written `@explicit_destroy` text, not a derivation. And the regime is
binary per type — `__del__` present means every abandonment auto-cleans,
absent means none do — so Koru's synthesized-backstop (`2104_15`, the one
row Mojo loses) is inexpressible without weakening every other guarantee on
the type.

## Where this lands in the landscape

Three points, three mechanisms: **Rust** is all default, zero refusal —
leaks are safe, abandonment can never be an error, the best analogue is a
runtime drop-bomb. **Mojo** is universal mandate, zero accounting — nothing
escapes death, nothing is chosen for you. **Koru** is a currency with a
central bank — named atoms on foreign types, netting across consume,
compiler-synthesized discharge — and pays for it in the defects only a
system that selects can have (`440_007`).

Also worth keeping honest: the enforcement is authored, not inherent, on
both sides. Remove `CheckLifetimes.cpp` and `!lit.ref` still verifies —
linearity was never in the IR. Koru's `<open!>` is likewise a marking until
`flow_checker.zig` reads it. No substrate hands you linearity; the difference
is who can write the atoms.

Related: [[frag-rust-proves-correct-use-not-use-at-all]],
[[frag-an-obligation-is-a-liveness-interval]].
