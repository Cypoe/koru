// TEST: field-subtraction on `computed` array inside for+each+captured
//
// Regression pin for the 910_LANGUAGE_SHOOTOUT/nbody energy loop —
// `c[i].x - c[j].x` under for+each in a captured update over the
// kernel-computed `[]Body` slice.
//
// Why this pin exists: the showcase wrote the subtraction UNSPACED —
// `c[i].x-c[j].x` — and hyphenated identifiers are legal Koru
// (`tor life-step`), so in this expression grammar `x-c` lexed as the
// identifier `x_c`, emitting `c[i].x_c[j].x` — a nonexistent field —
// which Zig then refused with "no field named 'x_c'". The parse was
// faithful to the lex; the source was wrong, silently, since
// unnumbered showcase dirs are not exercised by run_regression.sh.
//
// Asymmetry noted (2026-10-22, koruc @ dc2acc0aa): in bare-return
// position `a-b` passes through verbatim and Zig happens to read it as
// subtraction, while in this captured-update grammar `x-c[j]` binds as
// the identifier `x_c` indexed. Whether unspaced `-` should be
// identifier char, subtraction, or a rejected ambiguity is a language
// question — until answered, write subtraction spaced. This test pins
// the spaced spelling's emission and result.
//
// Expected: kernel:self advances x by 1.0 → {1,2,3};
// energy = Σ_j (1 - (j+1)) = -3.000000000.

import std/kernel
import std/io

std/kernel:shape(Body) {
    x: f64,
    mass: f64,
}

std/kernel:init(Body) {
    { x: 0.0, mass: 1.0 },
    { x: 1.0, mass: 2.0 },
    { x: 2.0, mass: 3.0 },
}
| kernel k |> std/kernel:self { k.x += 1.0 }
| computed c |> capture { energy: @as(f64, 0) }
    ! as acc |> for(0..3)
        ! each j |> captured { energy: acc.energy + c[0].x - c[j].x }
    | captured final |> std/io:print.blk { {{ final.energy:d:.9 }} }
