# 008_effect_dispatch — what an effect fire costs on .NET

One effect branch, `! tick`, fired once per call, 30M calls per rep, min of
3 reps. The question: how much does a Koru effect dispatch cost on C#, and
where does it go.

## What `generated` actually is

Not a paste — `run.sh` compiles `dispatch.kz` with `--lang=cs`, builds the
resulting `output_emitted.cs` into the benchmark assembly, and the harness
calls `main_module.beat_event.handler<BenchOps>` — the same public generic
method a real call site invokes, monomorphized on a harness ops struct
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
| `typed-io` | our dispatch surface with struct In/Out — the typed-envelope *hypothesis*, not current emission |
| `generated` | the real emitted handler: `handler<H>(dynamic, H)` + `Func<dynamic>` props + anonymous result object |
| `gen-noread` | generated minus the `.done` dynamic member read — isolates the DLR binder's share |
| `anon-func` | the previous k-sharp shape: dynamic anonymous handler object |

## Measured

Apple M-series (arm64), .NET 9 runtime executing a net8.0 target, Release.
30M calls/rep, min of 3.

| arm | min ms | ns/call | B/call |
|---|---:|---:|---:|
| direct | 9 | 0.3 | 0 |
| struct-method | 9 | 0.3 | 0 |
| virtual | 60 | 2.0 | 0 |
| typed-io | 67 | 2.2 | 0 |
| typed-func | 67 | 2.2 | 0 |
| gen-noread | 409 | 13.6 | 56 |
| **generated** | **398** | **13.3** | **56** |
| anon-func | 655 | 21.8 | 80 |

`DOTNET_JitDisasm` on the same shapes: `handlerM[MOps]` compiles to 20 bytes
(the empty `tick()` inlines to nothing), `handlerG[GOps]` to 92 B, the old
dynamic handler to 516 B. Per-struct monomorphization is real — `handlerG`
and `handlerM` each appear as their own `[ConcreteOps]` instantiation.

## What the numbers say

The struct-generic dispatch surface is **done** — it sits at the ~2.2ns
delegate floor (typed-io/typed-func), and the JIT receipt shows real
per-site monomorphization. The remaining ~11ns in `generated` is the
`dynamic` envelope, and it decomposes:

- `.done` member read through the DLR binder: ~0.7ns (gen-noread) — the
  call-site cache works.
- The rest is the envelope itself: an anonymous args object and an anonymous
  `new { tag, done }` result object allocated per call — 56B/call, 1.7GB of
  gen0 churn per 30M calls.

So the next factor-of-five is not in dispatch — it is typing the envelope:
the effect decl knows `q i64` in and `done i64` out. Emit `struct In` /
`struct Out` instead of `new { }` + `dynamic` and generated lands at
typed-io: ~2.2ns. Below that needs arms as struct *methods* (0.3ns), which
only works when the arm captures nothing — the `Func` indirection is the
price of closure capture.

Honest scope note: the result object in *this* fixture is host-authored —
`dispatch.kcs`'s `~proc beat|cs` writes `return new { tag = "done", done =
0 }` as opaque text, the same shape a compiler-generated produce emits.
The envelope cost is identical either way; typing applies only where the
emitter constructs the result, not inside opaque host text.

## Run

```sh
sh run.sh
```

Needs `zig build` (for `koruc`) and `dotnet` on PATH. ~30s, most of it the
emission and the Release build.
