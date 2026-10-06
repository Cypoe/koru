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
the first 012-series number that wasn't at the floor. Residual hunt, four
items:

1. `fmt:ln` → `fmt.blk`: removed the per-element anonymous object
   (2915 → 2707).
2. `__koru_str(dynamic v)` in the cs preamble boxed every value-type
   operand — `i % 256` is `long`, so each placeholder was a heap alloc.
   6M boxes ≈ 750ms. Fix: `__koru_str<T>(T v)` — the JIT specializes per
   operand type, no box (2707 → 1953). **A real compiler defect the
   benchmark exposed — fixed in `src/cs_emitter.zig`, benefitting every
   `{{ }}` placeholder on cs**, not a benchmark workaround.
3. `fmt.blk|cs`/`ln|cs` emitted `+` concat with `__koru_str(…)` per
   placeholder — a ToString substring per placeholder plus the concat
   result. Fix: emit the C# interpolated-string form `$"lit{expr}lit"`,
   which lowers to `DefaultInterpolatedStringHandler` — one pooled buffer,
   one allocation, digits written straight in. Numeric specs (`:d`/`:f`)
   get a bare `{expr}` hole; `:s`/bare/`:S` keep `__koru_str` inside the
   hole (bool semantics; free for strings). (1953 → ~1700).
4. `collect`'s cs shim folded the checksum into the timed loop —
   `hits += 1; chars += s.Length` per element — while every other arm
   checksums after the stopwatch. Fix: `collect` is only `results.Add`
   (the ToList); the harness checksums `KoruHost.results` post-timer,
   identical accounting to the LINQ/foreach arms. Disclosed in `task.kcs`.

## Measured (N=10,000,000, threshold=40, min of 7 reps, net8.0, arm64)

After steps 1–4, calm box (runaway browser processes killed):

```
generated    1481 ms   hits=6000000 chars=109921843
linq-array   1529 ms   hits=6000000 chars=109921843
linq-lazy    2505 ms   hits=6000000 chars=109921843
foreach      1518 ms   hits=6000000 chars=109921843
direct       1522 ms   hits=6000000 chars=109921843
zig           444 ms   hits=6000000 chars=109921843   (whole process, min of 3)
```

Three consecutive runs, same ordering vs LINQ every time: generated
1481/1465/1478 vs linq-array 1529/1500/1600 — generated beats both LINQ
arms in all three. Against handwritten it sits at the top of the pack:
one run had `foreach`'s best rep at 1386; the managed field otherwise
overlaps within noise (~±50ms). The pre-fix baseline on the same box was
generated 1953 vs linq-array 1622.

## Honest reading

- Generated **beats LINQ on both arms** — 1.03x over the array fast path,
  1.69x over the lazy `IEnumerable` the posted signature actually takes —
  and is indistinguishable from handwritten C#. The earlier claim that
  LINQ leads this field was true of the pre-fix emit; the fixes removed
  ~800ms of avoidable per-element allocation.
- This task is allocation-bound: ~6M strings × ~18 chars is ~110MB of GC
  traffic per rep. On alloc-bound work the enumerator overhead LINQ pays
  disappears into collection time — the remaining margin is the emit
  paying one allocation where the old shape paid three.
- `zig` (whole-process, includes startup) is ~3.4x the best .NET arm —
  the same source, no GC. Its role here is the cross-backend receipt:
  the program isn't a cs-shaped artifact.
- `fmt.blk` on zig allocates+frees per element (its `allocated!` debt
  discharges) where `fmt:ln` used a thread-local buffer — 196→469ms at
  the old measurement. The zig number would improve with `fmt:ln`; cs
  wouldn't. `fmt.blk` is kept because the benchmark's question is the
  LINQ post's task on .NET.
- `capture` is still a measured cs refusal (KORU047, `@typeInfo` has no
  lowering); the `~proc` statics stand in for custody, disclosed in the
  `.kcs`/`.kz` headers.
- Laptop numbers, even on a calmed box — treat the ±50ms band as real
  and the ordering as the finding.
