---
type: belief
id: frag-extent-pays-per-touch-not-per-declaration
provenance: brainfuck goose-race memory investigation 2026-10-21 — vmmap on
  the live process, BSS laziness probes (lazy vs touch), allocator A/B
  (page_allocator vs calloc vs malloc), interleaved bisect races of four
  kernel variants
ts: 2026-10-21
tags: [koru, grid, pool, memory, benchmarks]
---

# Extent pays per touch, not per declaration — laziness is already the grid's

Prior belief (this session's opening theory, inherited from staring at
`size: 262144` declarations): Koru's ~6x RSS gap on brainfuck vs the C
reference came from comptime-extent grids reserving giant BSS arrays, and
the fix would be a runtime-sized positional primitive. Measured, that was
wrong on the mechanism:

- `__DATA` is lazy. A 2MB grid left untouched costs ~0 resident (probe:
  1.44MB total, equal to an empty C program); the same grid fully written
  costs exactly its 2MB (3.52MB total). BSS is a lazy extent — declaration
  is free, the bill arrives per written page.
- The actual 4MB came from a KERNEL clear loop — `for(0..1048576)
  tape[i].v = 0` between the verify and timed runs. The reference callocs
  cap=1 and doubles on demand; it never pays the full extent either.
- On macOS even `calloc` eager-memsets (vmmap: MALLOC_LARGE 4MB dirty);
  the lazy spelling is `page_allocator` — fresh anonymous mmap, zero by
  OS contract, resident only where touched.

The primitive that resulted (`std/grid:pool`) works — slice-backed columns,
runtime extent, `__koru_size` floor — and pinned at 697_021. But it carries
a real cost the grid doesn't: `grid.f[i]` loads a slice pointer plus a
runtime `__koru_size` per access, and across handler call boundaries
neither hoists — measured +10% (ops) to +24% (tape) on the brainfuck
dispatch loop. The fixed-address `(&grid.f)[i]` shape is what keeps hot
loops fast.

The ruling: reach for a pool when the EXTENT is runtime — when no comptime
bound exists or the program must not commit the address space. For
fixed-extent-but-sparse tables, the grid is already lazy; the discipline
that pays is "clear what you touched" (a high-water mark beats a
full-extent memset), not a new storage kind. Kernels that churn dense data
(primes' 48MB trie) aren't an extent problem at all — that's cell size,
and no allocator spell fixes it.

Open questions: whether slice-indirect access can recover the fixed-address
shape inside loops (a cursor/cached-pointer vocabulary), and whether
non-zero-default pool columns deserve a lazy spell beyond alloc+fill.
