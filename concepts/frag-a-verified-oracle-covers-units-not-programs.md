---
type: belief
id: frag-a-verified-oracle-covers-units-not-programs
provenance: verify-path session 2026-10-11 — ccomp-produced .o linked into a zig binary (demonstrated in an aarch64-linux container), then recognized as the same seam |mlir already rides
ts: 2026-10-11
---

# A verified oracle's coverage is a lane assignment, not a program verdict (belief)

Whole-program parity — all-zig binary vs all-ccomp binary, compare stdout —
makes the oracle's coverage binary per program: one unexpressible construct
refuses the entire file, and the refusal table is a wall. The link seam
dissolves that. Demonstrated this session: `ccomp -c` produces a standard ELF
object, `zig build-exe` links it, the mixed binary runs and calls across the
boundary. So arm A can be zig-everything while arm B is zig for the non-C
units plus ccomp for the C-expressible units — and then the only controlled
variable in the comparison is *who compiled the C fragment*.

That is a stronger instrument than it looks. A zig miscompile inside a non-C
unit lands identically in both arms and cancels out of the comparison —
the oracle's verdict localizes to the fragment automatically, no harness
attribution needed. Coverage becomes each program's C-fraction instead of
requiring C-fraction == 1, and "cannot lower to C" stops being a refusal —
it becomes an entry in a coverage map.

The mechanism is not new, which is the other half of the belief: `|mlir` proc
bodies already AOT-compile to `.o` and link into the output binary through a
glob in generated `build_output.zig`, and `~std/build:requires` exposes the
same splice to users. A `|c` variant rides an existing seam — find it before
you build it applied to a foreign toolchain.

## What constrains the partition

Calls cross the seam; memory does not. Zig and C guarantee no common struct
layout, so shared state must flow through accessor functions — the cut runs
along call edges, not data edges. (The c-lane lowering table's "closed
accessor set → static" is the same boundary seen from the other side.)

## Open

Whether the partition machinery earns its cost before whole-program parity
exists at all. Current sequencing: whole-program first — the first green
cell needs zero partitioning — with the partition as the generalization that
makes the oracle reach past the sequential fragment.

## Evolve 2026-10-22 — the fragment's vocabulary, not its boundary, was the benchmark wall

Measured on the race corpus: the barrier holding live benchmarks out of the
C lane was not the fragment boundary (store views, watches, effect arms —
the refused census names them) but one missing builtin row: `@as`/`@intCast`,
the canonical counted-loop cast. Widening `lowerCInto` to the cast+arithmetic
family — `@as`, `@intCast`, `@floatFromInt`, `@divTrunc`, `@rem`, `@mod` —
moved 004/005 to whole-program parity immediately (`checksum 213186560` on
both lanes; ccomp ~20× slower, identical answer). The coverage lever is
expression vocabulary first, construct boundary second; the remaining wall
(KORU161 store surfaces, `RefusedConstruct` effect arms, `.kcs` raw host
lines) is the true fragment edge.

The faithfulness constraint that shapes the table: Zig's `@intCast` traps
out of range, so the lowering spells a checked helper (`__koru_intcast`)
rather than a bare C cast — a silent truncation would make the verified
binary less honest than the zig one it oracles. Residuals documented at the
table: usize sources ≥2^63, bare `@intCast` coercions — divergences the
race still surfaces as a verdict mismatch, not hidden wrongness.

## Evolve 2026-10-23 — a verbatim row that lies is worse than a refusal

The fragment's vow is "refuse what it cannot spell faithfully" — the cast
rung kept it by checking `@intCast`. The `==`/`!=` pair broke it differently:
it emitted *verbatim*, compiled clean under ccomp, and answered pointer
equality where Koru means value equality — a wrong verdict wearing a green
emit. Coverage-by-compilation is not coverage-by-verdict; an oracle that
silently diverges is worse than one that refuses, because the refusal is
audible.

The fix was possible only because the binding registry (`int_bindings`,
misnamed — it carries every minted cell's C type) already resolved string
cells to `const char *`: `__koru_streq` now emits whenever an operand types
as a string (a `"` literal or a registered binding), and unproven pairs keep
the verbatim residual rather than guess — the same discipline the wrap ops
apply to width. The residual class is member-read-vs-member-read and call
results: narrower than the old all-verbatim gap, never zero at the text
level.

Found in the same pass, on the *other* lane: the zig emitter's string-eq
block hard-labeled `blk:`, which collided with any enclosing labeled block
(arrow bodies, result binds) — string `==` inside an inlined body refused
natively while the C lane it oracles handled the case fine. Now gensym'd
`__koru_eq{d}` per emitted block. Lesson folded in: label collisions are a
class — any generated Zig label that isn't unique-per-emission is a latent
collision; `__koru_str` stays fixed because it can never nest inside itself.
