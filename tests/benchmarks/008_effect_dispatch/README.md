# 008_effect_dispatch — what an effect fire costs on .NET

One effect branch, `! tick`, fired once per call, 30M calls per rep, min of
3 reps. The question: how much does a Koru effect dispatch cost on C#, and
where does it go.

## What `generated` actually is

Not a paste — `run.sh` compiles `dispatch.k` with `--lang=cs`, builds the
resulting `output_emitted.cs` into the benchmark assembly, and the harness
calls `main_module.beat_event.handler<BenchOps>` and
`main_module.pulse_event.handler<PulseOps>` — the same public generic
methods a real call site invokes, monomorphized on harness ops structs
standing in for the emitted (private) `__koru_handlers_N`. If the emission
shape changes, this file stops compiling. That is the pin.

The arm bodies all do identical work: `fires++` on a shared static, checked
to equal N per arm — a benchmark whose arms do different work measures
nothing.

## Comparator set (declared before running)

| arm | shape |
|---|---|
| `direct` | static call to a static body — the atom |
| `struct-method` | `where H : struct, IOps` with `void tick()` *methods* — the handwritten analogue of `comptime __H` |
| `virtual` | interface call on a class — classic OOP dispatch |
| `typed-func` | our `IOps`/`Func`-property surface, but typed payloads (`Func<int>`, `int` in/out) |
| `typed-io` | our dispatch surface with struct In/Out — a hypothesis arm |
| `gen-subflow` | the real emitted handler for `pulse` — a pure-Koru impl (`pulse = tick() => done 0`), so the emitter generates the produce: `handler<H>(Input, H) → Output`, all structs |
| `generated` | the real emitted handler for `beat` — an opaque `\|cs` impl, so the envelope stays `dynamic` (host text constructs its own result object) |
| `gen-noread` | generated minus the `.done` dynamic member read — isolates the DLR binder's share |
| `anon-func` | the previous k-sharp shape: dynamic anonymous handler object |

## Measured

Apple M-series (arm64), .NET 9 runtime executing a net8.0 target, Release.
30M calls/rep, min of 3.

| arm | min ms | ns/call | B/call |
|---|---:|---:|---:|
| direct | 9 | 0.3 | 0 |
| struct-method | 9 | 0.3 | 0 |
| virtual | 59 | 2.0 | 0 |
| **gen-subflow** | **66** | **2.2** | **0** |
| typed-io | 67 | 2.2 | 0 |
| typed-func | 66 | 2.2 | 0 |
| gen-noread | 417 | 13.9 | 56 |
| **generated (opaque impl)** | **386** | **12.9** | **56** |
| anon-func | 633 | 21.1 | 80 |

`DOTNET_JitDisasm` on the same shapes: `handlerM[MOps]` compiles to 20 bytes
(the empty `tick()` inlines to nothing), `handlerG[GOps]` to 92 B, the old
dynamic handler to 516 B. Per-struct monomorphization is real — `handlerG`
and `handlerM` each appear as their own `[ConcreteOps]` instantiation.

## What the numbers say

Two measurements in one table, because the second run landed a change the
first one predicted.

**The dispatch surface was already done.** Generic-struct `IOps` +
`Func` props sits at the ~2.2ns delegate floor — typed-io and typed-func
both read 66–67ms — and the JIT receipt shows real per-site
monomorphization.

**The envelope was the cost, and it is now typed.** The first run of this
benchmark decomposed `generated`'s 13.3ns: ~0.7ns DLR binder on `.done`,
~10.6ns the anonymous In/Out objects (56B/call of gen0 churn). The emitter
now ports zig's `Input`/`Output` pair: per-event `struct Input { public
long q }` / `struct Output { public string tag; public long done }`,
`handler<H>(Input, H) → Output`, `new ev_event.Input { … }` call sites,
`return new Output { tag = "done", done = a }` produces. The same harness,
same workload: **gen-subflow measures 2.2ns at 0 B/call** — the real
emitted code lands exactly on the hypothesis arm.

**The honest bound is the impl's opacity.** `beat`'s `~proc beat|cs` body
is opaque host text — it authors its own `new { tag, done }` return, so
its handler keeps `dynamic` in/out and stays at 12.9ns. The typed path
covers every impl the compiler generates (`immediate`, `subflow`); host
text is where the envelope ends.

Below 2.2ns needs arms as struct *methods* (0.3ns), which only works when
the arm captures nothing — the `Func` indirection is the price of closure
capture, and it costs ~1.9ns/call here.

## Run

```sh
sh run.sh
```

Needs `zig build` (for `koruc`) and `dotnet` on PATH. ~30s, most of it the
emission and the Release build.
