// 520_008: `->` produce of `"lit" ++ field` emits Zig `++` — a comptime-only
// concat — over a runtime operand. The emitted output_emitted.zig fails its
// own build: "unable to resolve comptime value / slice being concatenated
// must be comptime-known".
//
// Latency mechanism: Zig analyzes a function body only when the function is
// reached. greet_event.handler is reached HERE because the registered
// dispatcher calls it — a wire turn via std/bridge:run forces analysis.
// Plain call sites stay silent: `greet(name: "x")` constant-folds through
// the produce (the literal arg makes the whole concat comptime-known), and
// a folded call leaves the handler body unanalyzed — 020_014 passes with
// the identical produce because nothing ever calls its handler.
//
// Deferred by design: the honest fix is a runtime concat, which allocates —
// and ownership is a language-semantics question (produced runtime strings
// should carry string<allocated!> to a disposer), not an emission detail.
// See BUG.md.

import std/io
import std/bridge
import std/runtime
import std/interpreter

pub tor greet { name: string } -> string
greet -> "hello " ++ name

std/runtime:register(scope: "api") {
    greet(5)
}

[with]std/bridge:create(id: "repro", scope: "api"): br
|> std/bridge:run(br, source: "greet(name: \"assistant\")")
  | result r |> std/interpreter:value.stringify(r.value): j |> std/io:print.ln("said: {{ j:s }}")
  | error e |> std/io:print.ln("failed: {{ e.kind:s }}")
