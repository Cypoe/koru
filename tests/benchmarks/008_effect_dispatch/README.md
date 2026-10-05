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
| `generated` | the real emitted handler for `beat` — an opaque `\|cs` impl under the same contract: host text produces `new Output { tag = "done", … }`, compile-enforced |
| `gen-dynread` | the typed `Output` consumed through `dynamic` — boxing + DLR binder, what the typed envelope saves a typed consumer |
| `anon-func` | the previous k-sharp shape: dynamic anonymous handler object |

## Measured

Apple M-series (arm64), .NET 9 runtime executing a net8.0 target, Release.
30M calls/rep, min of 3.

| arm | min ms | ns/call | B/call |
|---|---:|---:|---:|
| direct | 9 | 0.3 | 0 |
| struct-method | 9 | 0.3 | 0 |
| **gen-subflow** | **9** | **0.3** | **0** |
| **generated (opaque impl)** | **9** | **0.3** | **0** |
| virtual | 61 | 2.0 | 0 |
| typed-func | 67 | 2.2 | 0 |
| typed-io | 67 | 2.2 | 0 |
| gen-dynread | 301 | 10.0 | 56 |
| anon-func | 640 | 21.3 | 80 |

`DOTNET_JitDisasm` on the same shapes: `handlerM[MOps]` compiles to 20 bytes
(the empty `tick()` inlines to nothing), `handlerG[GOps]` to 92 B, the old
dynamic handler to 516 B. Per-struct monomorphization is real — `handlerG`
and `handlerM` each appear as their own `[ConcreteOps]` instantiation.

## What the numbers say

Four measurements in one table, each landing a change the previous one
predicted. The last one closed the file: **every real generated arm —
compiler-written impl or opaque `|cs` host text — measures identical to
`direct`, the static-call atom.**

**The dispatch surface landed at the atom.** Non-resuming effect arms
emit as *methods* on the ops struct — `IOps` declares `void tick()`, the
call-site struct implements it, and `handler` calls `ops.tick()` through
a local-function shim. The JIT devirtualizes the struct-constrained call
and inlines the arm body into `handler`, which inlines into the loop.
The ~2.2ns `Func`-delegate floor (typed-func/typed-io) is what the
previous property surface still would have paid.

**The envelope is typed end to end — including host text.** The emitter
ports zig's `Input`/`Output` pair: `handler<H>(Input, H) → Output`,
`new ev_event.Input { … }` call sites, `new Output { tag = "done", … }`
produces. The last move made the typed `Output` the *contract* for
opaque `|cs` bodies too — host text that used to return anonymous
`new { tag, done }` now writes `new Output { tag = "done", … }` and the
C# compiler enforces it. That is what moved `generated` from 10.8ns to
the atom: there is no `dynamic` left on the path.

**What `dynamic` still costs, measured honestly:** `gen-dynread` reads
the same typed `Output` through a `dynamic` reference — boxing +
call-site binder — and pays 10.0ns + 56B/call for it. The typed
envelope's win is exactly that, per consumer.

**Captures are fields, not closures.** Zig's nested `Handlers_N` fns
const-capture enclosing bindings natively; C# methods can't, so the
emitter scans each arm body for references to enclosing flow locals and
materializes them as `__cap_*` struct fields — the same snapshot
semantics, spelled. An arm body that references something the scanner
can't prove (host-text locals) falls back to a stored `Func` forwarded
by the method — the interface stays statically callable, the
pathological arm pays the old price.

**What is left of `Func`:** only optional *resuming* arms keep nullable
`Func<dynamic,dynamic>` properties — presence is observable
(`ask != null`), a method has no "absent" spelling. And wildcard-input
tors keep `dynamic` input — their members cannot be named at decl time.

## Run

```sh
sh run.sh
```

Needs `zig build` (for `koruc`) and `dotnet` on PATH. ~30s, most of it the
emission and the Release build.
