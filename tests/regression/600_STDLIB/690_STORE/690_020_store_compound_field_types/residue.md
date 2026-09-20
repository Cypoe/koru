# 690_020 — compound store field types (residue pin)

Pinned 2026-07-05 (Lars: "pin it as 690_020"), out of the ecs-store gap
analysis. Residue-tier: the field-type surface is uninvented, so no
`input.kz` — this file carries the design residue until a spelling pin
supersedes it.

## The gap

Store columns are i64-only — a deliberate rung-one loud wall
(`@compileError` on non-i64 fields). The ecs_bench_suite mapping
(DESIGN.md "perf north star") makes this the single prerequisite shared by
ALL one-to-one entries:

- `simple_insert` / `simple_iter`: `Position/Rotation/Velocity(vec3)` +
  `Transform(mat4x4)` columns — f32 compound types.
- `heavy_compute`: a `mat4x4` column swept with a heavy body.

No other 690 pin touches the column type system; 690_009–019 are all
semantics.

## Evidence the wall is scoping, not architecture

`std/kernel:shape` declares f64 fields and is green in the corpus —
`390_001_shape_basic` runs `~std/kernel:shape(Body) { x: f64, y: f64,
z: f64, vx: f64, vy: f64, vz: f64, mass: f64 }` through the same
transform substrate (`koru_std/kernel.kz`) that `store.kz` uses. Float
columns demonstrably work in a `[transform]`-minted layout today. Extending
store's `create` from `entities: 0[i64]` to f32/f64 seeds is extension,
not invention.

## The three tiers (each a separate step; only tier 1 is obviously cheap)

1. **Scalar widening** — f32/f64 (and other int widths) column types with
   seeded and bare-type declarations. Kernel precedent applies directly.
   **TIER 1 SHIPPED for singletons (2026-07-05, spelling pin 690_021
   GREEN):** uniform-type i64/i32/f64/f32 seeded columns flow through
   the whole write path (cell, apply/write value type, envwrite, peek/
   announce). Mixed-type stores and PLURAL column widening are walled
   loudly (per-field write events / typed SoA columns = the remainder
   of this tier).
2. **Fixed-arity vector fields** — `vec3`-shaped columns. Substrate
   candidate: 2-D cells (320_057, the indexed-lvalue shape O2's handle
   head already leans on). Open: is a vec3 one column of 3-lane elements
   (SIMD-friendly, SoA-of-vec) or three scalar columns the planner groups
   (pure SoA)? That is a PLANNER call under "the queries are the layout" —
   the declaration should not encode it.
3. **Matrix fields** — mat4x4. Same question one level up, plus
   interaction with the stripe's fused loop (a 64-byte row element changes
   the bandwidth math O13's napkin used).

## Watch/delta semantics question (needs ruling before tier 2)

A scalar column's watch fires on a value change with `{old, new}` scalars.
What does a *vec3* column's watch observe — whole-vector change (one event,
vector payload) or per-lane (three events)? Lean: whole-vector — a field is
the unit of write (`stored { game[r].pos: ... }`), so it is the unit of
observation; per-lane granularity is a query/projection concern, not an
event-vocabulary concern. Genuine ruling, Lars's.

## Spelling — DO NOT INVENT

Existing grounded shapes to extend from, when the walk happens:
- seeded scalar: `entities: 0[i64]` (690_001, matches `{ oval: 0[i32] }`
  320_036); bare-type: `hp: i64` (matches kernel shape fields 390_001).
- f64 field decl exists verbatim in kernel: `x: f64` (390_001).
- vec/mat declaration syntax for store columns: NO corpus precedent —
  uninvented, needs the walk.

## Promotion path

residue pin (this) → spelling pin per tier (provisional input.kz, honest
red) → green as `create` accepts each tier. Tier 1 may be promotable
almost immediately once rung-two work opens store.kz anyway.

## Tier 2/3 substrate — MEASURED (2026-09-20, probe `mat_shape_ab`)

The open question above asked whether a vec/mat column should be one
compound cell (SoA-of-vec) or scalar leaves the planner groups (pure SoA).
Measured on the workload that motivated it — the 690_127 mat4 inverse,
10k rows x 200 passes, identical math and identical sinks:

| shape | ns/pass |
|---|---|
| 32 flat scalar columns (today's emission) | ~80,000 |
| one `[16]f64` cell per row, math comptime-unrolled | ~153,000 |
| same cells under a runtime ranged loop | ~121,000 |

Flat leaves win 1.9x and the mechanism is visible in the disassembly:
scalar columns let LLVM vectorize ACROSS ROWS (`ldr q` / `fmul.2d` carry
two rows per op through the whole cofactor graph). A row-local array is a
scalar dependency chain — no vector ever forms inside one row's inverse.
The residue's earlier guess ("one column of N-lane elements is
SIMD-friendly") was backwards for this workload: the SIMD dimension is the
row axis, not the element axis.

Consequence for the design: a compound field should DECLARE like a unit
and FLATTEN like a proto field — `t: [4][4]f64` → sixteen leaf columns via
the `ProtoExpander` path that already mints `left.health` from
`Limb.health`. A ranged write (`stored` entry whose LHS indexes the
declared extents — spelling NOT invented, Lars's) unrolls at transform
time into today's envelope shape, so the emitted code keeps the winning
layout. No compound-cell substrate is needed for performance.

What that leaves real: (a) the 64-column write mask — one 4x4 pair already
spends 32 bits, so wide tables need chunked envelopes or a wider mask;
(b) the watch ruling below narrows — leaves are scalar columns, so the
question becomes whether `! pos` on a compound field is a grouped event
worth spelling at all, not which payload a cell carries.

Probe: `koru-benchmarks/suites/ecs-store/probes/zig/mat_shape_ab.zig`
(commit `4ee8c2d`), one variant per process, argv `a|b|c`.
