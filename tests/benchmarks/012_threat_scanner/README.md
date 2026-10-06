# 012_threat_scanner

The X post this work answers, verbatim. The post's code — a LINQ pipeline
canonical enough to be its marketing shape:

```csharp
return activeSessions
    .Where(s => s.ThreatScore >= threshold)
    .Select(s => $"{s.IpAddress} [{s.ThreatLevel}]")
    .ToList();
```

`Program.cs` carries `ThreatScanner.LatestResults` character-for-character.
The generated arm is `task.k` compiled with `--lang=cs` and invoked through
`main_module.run_event.handler`; the same `task.k` is also compiled native
(`koruc build --release=fast`) and timed as a whole process — one source,
two backends.

## The Koru shape

```
run = for(0..n)
    ! each i when (i * 31) % 100 >= threshold      <- Where
        |> level-name(l: i % 4): lvl               <- cond cascade
        |> std/fmt:fmt.blk {10.0.0.{{ i % 256 }} [{{ lvl }}]}: s  <- Select
        |> collect(s)                              <- ToList
```

Sessions are derived from `i` — the producer is `for` + `! each`, pure `.k`
(the LINQ post's own producer discipline). `collect` is a disclosed `~proc`
shim (`List<string>.Add` on cs, `ArrayList.append` on zig) standing in for
custody — same boundary 010/011 disclose; the claim under test is the
pipeline, not the bookkeeping.

`fmt.blk` (not `fmt:ln`) is the measured spelling: `ln` produces a `{text}`
record — `new { text = … }` is a per-element heap allocation LINQ doesn't
pay — while `fmt.blk`'s `: s` bind yields the bare formatted string. Both
were measured; `fmt:ln` cost ~200ms/6M elements more and is not the right
tool when all you want is the string.

## What the benchmark found

First measured run, `generated` **lost**: 2915ms vs `linq-array`'s 1627 —
the first 012-series number that wasn't at the floor. Residual hunt:

1. `fmt:ln` → `fmt.blk`: removed the per-element anonymous object
   (2915 → 2707).
2. `__koru_str(dynamic v)` in the cs preamble boxed every value-type
   operand — `i % 256` is `long`, so each placeholder was a heap alloc.
   6M boxes ≈ 750ms. Fix: `__koru_str<T>(T v)` — the JIT specializes per
   operand type, no box (2707 → 1953). **A real compiler defect the
   benchmark exposed — fixed in `src/cs_emitter.zig`, benefitting every
   `{{ }}` placeholder on cs**, not a benchmark workaround.

## Measured (N=10,000,000, threshold=40, min of 3)

```
generated    1953 ms   hits=6000000 chars=109921843
linq-array   1622 ms   hits=6000000 chars=109921843
linq-lazy    2682 ms   hits=6000000 chars=109921843
foreach      1903 ms   hits=6000000 chars=109921843
direct       1733 ms   hits=6000000 chars=109921843
zig           467 ms   hits=6000000 chars=109921843   (whole process)
```

## Honest reading

- Generated sits **inside the handwritten pack** (direct 1733, foreach
  1903, generated 1953) — not at the top, not an outlier. This task is
  allocation-bound: ~6M strings × ~18 chars is ~110MB of GC traffic per
  rep, and on alloc-bound work the enumerator overhead LINQ pays
  disappears into collection time. `linq-array` leads the whole field —
  the array-specialized Where/Select iterators plus the interpolated-
  string handler is genuinely .NET's best spelling for this task.
- The ~220ms residual over `direct` is the `level-name` subflow call
  (struct Input + `dynamic` return → virtual ToString on `lvl`) — a real
  per-element cost the emitted code pays and the fused loop doesn't.
  Named, not hunted further: removing it would mean writing the Select
  into host text, which is the fraud shape these benchmarks exist to
  prevent.
- `zig` (whole-process, includes startup) is 4x the .NET field — the same
  source, no GC. Its role here is the cross-backend receipt: the program
  isn't a cs-shaped artifact.
- `fmt.blk` on zig allocates+frees per element (its `allocated!` debt
  discharges) where `fmt:ln` used a thread-local buffer — 196→469ms. The
  zig number would improve with `fmt:ln`; cs wouldn't. `fmt.blk` is kept
  because the benchmark's question is the LINQ post's task on .NET.
- `capture` is still a measured cs refusal (KORU047, `@typeInfo` has no
  lowering); the `~proc` statics stand in for custody, disclosed in the
  `.kcs`/`.kz` headers.
