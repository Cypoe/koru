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
