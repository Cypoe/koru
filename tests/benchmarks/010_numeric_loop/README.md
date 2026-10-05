# 010 — numeric loop (cs)

Does a generated Koru `for` loop — the language's own iteration construct,
with an effect hop per element — cost what handwritten C# costs?

`run.sh` emits `loop.k` + `loop.kcs` with `--lang=cs` into
`output_emitted.cs`, compiles it **into** the benchmark assembly, and times
`main_module.run_event.handler` — the real emitted entry — against
handwritten C# shapes doing identical work (`work = i*i+i` + accumulate,
100M elements, min of 3 reps).

## Verdict method

Timing alone cannot answer this on a laptop — instruction-equivalent loops
here measure anywhere from 0.5 to 2.0 ns/elem depending on how the
scheduler interleaves work around the dependency chain. So the verdict
instrument is `DOTNET_JitDisasm`, not the stopwatch:

```
generated OSR loop (main_module.run_event.handler):

  sxtw x0, w1            ; i
  madd x2, x0, x0, x2    ; acc = i*i + acc  — work() inlined+fused,
                         ;                    acc LIVES IN x2
  add  x2, x2, x0        ; acc += i        — acc() inlined to a local write
  add  w1, w1, #1
  sxtw x0, w1
  cmp  x0, x3
  blt  loop
  ...
  movz/movk/movk x0      ; build &KoruHost.total
  str  x2, [x0]          ; ONE store — the writeback, after the loop
```

Seven instructions, the accumulator register-resident the whole loop —
the same shape as `direct` (a handwritten register-local loop). `work`'s
call and `Input` structs inlined away; `acc`'s `|cs` body spliced at the
call site so its cell write binds the hoisted local; the cell written back
to `KoruHost.total` exactly once, after the loop.

## How the emitter earns that shape

Koru has no variables — a cell's complete accessor list is the program
text, so the emitter can prove nothing observes `KoruHost.total` while the
handler runs and materialize it as a local. Three pieces in
`src/cs_emitter.zig`:

1. **Cell registry** — `collectCsCells` scans `.kcs` host lines for
   `static class <Owner> { static <T> <name> }` fields.
2. **Call-site inlining** — a return-free opaque `|cs` impl splices its
   body at the call site (`tryEmitInlinedProcCall`), params rebound to
   `__koru_p_<name>`, so the body — including its cell writes — lands in
   the caller's scope.
3. **Hoist + writeback** — `emitEventDecl` buffers the handler body, and
   for every registered cell it names bare, emits `var <cell> =
   <Owner>.<cell>` up top and `<Owner>.<cell> = <cell>` after.
   `cellMayHoist` refuses when safety isn't provable: a `return` in the
   body (early writeback would be skipped), a `=>` lambda (can outlive the
   region and reads the static), a qualified `Owner.name` mention
   (bypasses the local), a same-named local declaration, or any callee
   behind a `handler(` boundary whose impl touches the cell
   (`calleeMentionsIdent` walks call targets; subflows/template stubs
   count as mentions — uninspectable text is conservative).

Earlier versions of this file recorded a residual: the per-element
`ldr`+`str` on the named cell vs `direct`'s register loop, and claimed the
language could not emit the register shape. That claim was wrong — it was
an emitter gap, and the no-variables property is exactly what makes the
fix provable rather than guessed. Corrected 2026-10-05.

## Measured (this machine, net8.0 ARM64, 100M elems, min of 3)

```
generated           121 ms      0 B/elem   ← register shape
twin                161 ms      0 B/elem   ← keeps the static-write shape
func                 39 ms      0 B/elem
virtual             204 ms      0 B/elem
direct-static       203 ms      0 B/elem
direct-int          120 ms      0 B/elem
direct              119 ms      0 B/elem   ← generated == direct
```

All arms produce the identical sum — the correctness control. Every arm
allocates zero bytes per element, generated included.

The remaining timing spread on near-identical streams is microarchitectural
luck; the disassembly is the claim, and after `for|cs` started emitting a
`long` counter (the `var` off `0` bound `int`, costing two `sxtw` per
element against a `long` bound) the generated hot loop is *instruction-
identical* to `direct` — five instructions: `madd; add; add; cmp; blt`.
