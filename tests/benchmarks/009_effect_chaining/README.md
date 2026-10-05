# 009_effect_chaining — a value through K effect hops vs LINQ

008 answered "what does one fire cost" (0.3ns — the atom). This one asks
what a *chain* costs: a value passed through K=8 resuming effect arms —
`step(x): a |> step(a): b |> … |> step(g): h => done h` — per call,
30M calls per rep, min of 3 reps. The question: does Koru's
effect-branch chaining beat the canonical C# composition idiom?

## What `generated` actually is

Not a paste — `run.sh` compiles `chain.k` with `--lang=cs`, builds the
resulting `output_emitted.cs` into the benchmark assembly, and the
harness calls `main_module.chain_event.handler<ChainOps>` — the same
public generic method a real call site invokes, monomorphized on a
harness ops struct standing in for the emitted (private)
`__koru_handlers_N`. If the emission shape changes, this file stops
compiling. That is the pin.

The emitted impl body is eight sequential calls through the
local-function shim:

```csharp
public static Output handler<H>(Input __koru_input, H ops) where H : struct, IOps {
    long step(long __koru_arg) => ops.step(__koru_arg);
    var a = step(x); … var h = step(g);
    return new Output { tag = "done", done = h };
}
```

`ops.step` is a struct-constrained interface method — devirtualized,
inlined, and (as `v + 1` eight times) constant-foldable by the JIT.

## Comparator set (declared before running)

| arm | shape |
|---|---|
| `direct` | K fused `v += 1` adds in a handwritten loop — the atom |
| `generated` | the real emitted chain handler, `ChainOps.step = v + 1` |
| `virtual` | K calls through an `IStep` interface stage per element — OOP composition |
| `func-chain` | K composed `Func<long,long>` invokes per element — composition without enumerators |
| `linq` | `Enumerable.Range(0,N).Select(×8).Sum()` — the canonical LINQ chain |

The LINQ arm is the honest target: it is what a C# program writes when
it wants K chained transformations over N values. Enumerators are built
once per rep — the measured cost is per-element `MoveNext`/`Current`
hops plus the per-stage delegate call, not allocation churn.

## A protocol bug this benchmark caught

The first draft put `fires++` (a shared static) inside the generated
ops arm to prove the arm ran — and generated measured 81ms, slower than
virtual. The counter *was* the slowdown: eight serialized
read-modify-write hops on one static per element, a dependency chain the
LINQ arm never pays. The fix made the check stronger, not weaker: every
arm moves the same values through the same stages, so every sum must
equal the closed form `N(N-1)/2 + N·K` — a stage that never ran shows
up as a wrong sum. Control out of the hot loop; parity check kept.

## Measured

Apple M-series (arm64), .NET 9 runtime executing a net8.0 target,
Release. 30M values × 8 stages per rep, min of 3.

| arm | min ms | ns/element | B/call |
|---|---:|---:|---:|
| direct | 8 | 0.27 | 0 |
| **generated** | **15** | **0.50** | **0** |
| virtual | 19 | 0.63 | 0 |
| func-chain | 24 | 0.80 | 0 |
| linq | 647 | 21.6 | 0 |

## What the numbers say

**The generated chain beats every composition idiom C# offers — 43×
over LINQ** — and lands within 2× of a fused handwritten loop. The
residual over `direct` (~7ms) is the `Input`/`Output` struct envelope
around the fused adds; the K hops themselves inlined away entirely —
`step` as a struct method is what makes that legal for the JIT.

LINQ's 21.6ns/element is the composition tax paid per stage per
element: each `Select` wraps the previous enumerator, so a value climbs
K `MoveNext` calls + K delegate invokes to reach `Sum`. Delegates alone
(`func-chain`, no enumerators) are 0.8ns — LINQ's extra ~21ns is the
pull-enumeration machinery, not the lambdas.

`virtual` at 0.63ns is the JIT devirtualizing a monomorphic call site —
it stays a class-based pipeline and still loses to the struct method
because each call must reload `v` through the call boundary.

## Run

```sh
sh run.sh
```

Needs `zig build` (for `koruc`) and `dotnet` on PATH. ~40s, most of it
the emission, the Release build, and LINQ's warmup.
