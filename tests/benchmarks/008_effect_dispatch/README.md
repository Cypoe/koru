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
| `typed-func` | the `Func`-delegate floor: `Func<int>` props, `int` in/out — what the previous surface cost with the envelope typed |
| `typed-io` | `Func`-delegate dispatch with struct In/Out — a hypothesis arm for the envelope port |
| `gen-subflow` | the real emitted handler for `pulse` — a pure-Koru impl (`pulse = tick() => done 0`): `handler<H>(Input, H) → Output`, all structs, arm installed as a `void tick()` **method** on the ops struct |
| `generated` | the real emitted handler for `beat` — an opaque `\|cs` impl, so the envelope stays `dynamic` (host text constructs its own result object); the arm call is a method, same as `gen-subflow` |
| `gen-noread` | generated minus the `.done` dynamic member read — isolates the DLR binder's share |
| `anon-func` | the previous k-sharp shape: dynamic anonymous handler object |

## Measured

Apple M-series (arm64), .NET 9 runtime executing a net8.0 target, Release.
30M calls/rep, min of 3.

| arm | min ms | ns/call | B/call |
|---|---:|---:|---:|
| direct | 9 | 0.3 | 0 |
| struct-method | 9 | 0.3 | 0 |
| **gen-subflow** | **9** | **0.3** | **0** |
| virtual | 62 | 2.1 | 0 |
| typed-func | 69 | 2.3 | 0 |
| typed-io | 73 | 2.4 | 0 |
| **generated (opaque impl)** | **324** | **10.8** | **56** |
| gen-noread | 367 | 12.2 | 56 |
| anon-func | 631 | 21.0 | 80 |

`DOTNET_JitDisasm` on the same shapes: `handlerM[MOps]` compiles to 20 bytes
(the empty `tick()` inlines to nothing), `handlerG[GOps]` to 92 B, the old
dynamic handler to 516 B. Per-struct monomorphization is real — `handlerG`
and `handlerM` each appear as their own `[ConcreteOps]` instantiation.

## What the numbers say

Three measurements in one table, each landing a change the previous one
predicted.

**The dispatch surface landed at the atom.** Non-resuming effect arms now
emit as *methods* on the ops struct — `IOps` declares `void tick()`, the
call-site struct implements it, and `handler` calls `ops.tick()` through a
local-function shim. The JIT devirtualizes the struct-constrained call and
inlines the arm body into `handler`, which inlines into the loop:
**gen-subflow measures 0.3ns at 0 B/call — identical to `direct` and
`struct-method`.** Generated Koru dispatch costs exactly what a static C#
call costs. The ~2.3ns `Func`-delegate floor (typed-func/typed-io) is what
the previous property surface still would have paid.

**The envelope was the earlier cost, and it is typed.** The first runs of
this benchmark decomposed `generated`'s 13.3ns into ~10.6ns of anonymous
In/Out objects (56B/call of gen0 churn) plus a small DLR binder share. The
emitter ports zig's `Input`/`Output` pair: per-event `struct Input` /
`struct Output { tag, done }`, `handler<H>(Input, H) → Output`,
`new ev_event.Input { … }` call sites — zero allocation on the
compiler-generated path.

**Captures are fields, not closures.** Zig's nested `Handlers_N` fns
const-capture enclosing bindings natively; C# methods can't, so the
emitter scans each arm body for references to enclosing flow locals and
materializes them as `__cap_*` struct fields — the same snapshot
semantics, spelled. An arm body that references something the scanner
can't prove (host-text locals in opaque bodies) falls back to a stored
`Func` forwarded by the method — the interface stays statically callable,
the pathological arm pays the old price.

**The honest bound is the impl's opacity.** `beat`'s `~proc beat|cs` body
authors its own `new { tag, done }` return, so its envelope stays
`dynamic` — 10.8ns, and the method-arms change already shaved the ~2ns
delegate invoke off its earlier 12.9. Optional *resuming* arms keep their
nullable `Func` properties: presence is observable (`ask != null`), so
they can't be methods — they are the one arm kind that still pays
delegate invoke.

## Run

```sh
sh run.sh
```

Needs `zig build` (for `koruc`) and `dotnet` on PATH. ~30s, most of it the
emission and the Release build.
