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
scheduler interleaves the per-element static write with the independent
multiply. So the verdict instrument is `DOTNET_JitDisasm`, not the
stopwatch:

```
generated OSR loop (main_module.run_event.handler):

  sxtw x3, w1           ; i
  madd x3, x3, x3, x3   ; work(i) = i*i + i   — inlined, fused
  ldr  x4, [x0]         ; total
  add  x3, x4, x3       ; acc(r): total += r  — inlined
  str  x3, [x0]
  add  w1, w1, #1
  sxtw x3, w1
  cmp  x3, x2
  blt  loop
```

The handwritten twin (`twin` arm — int counter, static work method, static
acc method writing a static cell, hand-spelled exactly as emitted)
compiles to a byte-for-byte equivalent 9-instruction loop. The `Input`
structs, the handler calls, the dispatch — all inlined away. **Parity with
the same-shape handwritten program is proven at the instruction level.**

## The one real residual

`direct` (register-local accumulator) is a 5-instruction loop — `madd, add,
add, cmp, blt` — because a C# local never touches memory. The generated
program cannot produce that shape: `total` is *named module state*, which
is a memory cell by semantics, not a register. The residual cost of the
Koru shape is one `ldr`+`add`+`str` per element — the price of state being
a named place, which is the language working as designed, not emission
overhead.

## Measured (this machine, net8.0 ARM64, 100M elems, min of 3)

```
generated            51 ms      0 B/elem
twin                161 ms      0 B/elem   ← instruction-identical; the 3x
func                 42 ms      0 B/elem      spread is microarch, not code
virtual             203 ms      0 B/elem
direct-static       204 ms      0 B/elem
direct-int          121 ms      0 B/elem
direct              121 ms      0 B/elem
```

All arms produce the identical sum — the correctness control. Every arm
allocates zero bytes per element, generated included.

The `generated`/`twin`/`direct-static` spread on identical instruction
streams is Apple-silicon store-forwarding luck — included above precisely
because it demonstrates why the timing table is not the verdict; the
disassembly is.
