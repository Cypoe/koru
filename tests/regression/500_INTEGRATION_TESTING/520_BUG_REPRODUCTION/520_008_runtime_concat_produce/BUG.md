# BUG: `->` produce of `"lit" ++ field` emits comptime-only Zig concat

## Status
**OPEN** — deferred: the fix is a string-allocation/ownership decision,
not an emission detail.

## Symptom
A produce whose body concatenates a literal with a runtime operand emits
Zig `++`, which is comptime-only:

```koru
pub tor greet { name: string } -> string
greet -> "hello " ++ name
```

```zig
// output_emitted.zig
return "hello " ++ name;   // error: slice being concatenated must be comptime-known
```

## Why it stayed latent

Zig analyzes a function body only when the function is *reached*. Two
hiding spots kept this invisible:

1. **Uncalled handlers.** `020_014_pure_subflow_impl` has carried the
   identical produce (`"Hello, " ++ name ++ "!"`) green for months —
   nothing calls `greet_event.handler`, so the broken body is never
   sema'd.
2. **Constant folding at call sites.** `greet(name: "x")` folds the whole
   concat at comptime; even `echo(s: "lit"): a |> greet(name: a)` folds,
   because `a` resolves to a comptime-known string.

The paths that expose it are the ones that matter: `runtime:register`
generates a dispatcher that *calls* the handler — so a wire turn
(`std/cell:run`, `std/bridge:run`) forces analysis and the emitted
program fails its own build. Every `greet -> "hello {{ name:s }}"`
example in the cell suite only ever printed `r.bound`, which is the
interpreter's binding name (`r1`), not the value — so the produce body
was never observed either.

## What the honest fix looks like

Runtime concat allocates. `koru_allocator()` is leak-metered in Debug —
an untracked concat result converts this compile error into a guaranteed
leak-check failure, and `page_allocator` would hide the alloc from the
meter ("a METER, not a mop"). The semantically consistent answer is that
a runtime-concat produce yields `string<allocated!>` — the obligation
rides to the caller and discharges via `std/io:free`, same contract as
`std/fmt:fmt` results. That decision (and `{{ }}` interpolation living at
the fmt/print boundary, not in string literals) is the real work — this
bug is pinned so the seam is named until then.

## Reproduction

`input.kz` — a registered `greet` whose produce is `"hello " ++ name`,
dispatched through `std/bridge:run` so the handler is sema'd. Fails at
`zig build` of `output_emitted.zig`:
`unable to resolve comptime value — slice being concatenated must be
comptime-known`.
