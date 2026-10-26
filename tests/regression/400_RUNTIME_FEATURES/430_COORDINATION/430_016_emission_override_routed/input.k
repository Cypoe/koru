// Test 430_016: emission is a routed stage, not a leaf proc — and
// materialization is pipeline steps, not a driver tail.
//
// std/compiler:emission is [comptime|abstract] — overridable on its own,
// without touching coordinate. This override re-spells the default route:
// inject-ccp |> pass-dead-strip |> target-of selects the target arm; the
// zig arm spells the materialization steps raw (emit |> write-artifact,
// then branch on deep-check into validate-emitted | host-build-zig) to
// pin that every stage is a named, user-callable tor — emit-only
// pipelines are a user-space decision. The js/cs/other arms use the
// composed emit-*-artifact tors, which spell the same chain.
import std/compiler
import std/io

std/compiler:emission = std/compiler:inject-ccp(ctx): c1
|> std/compiler:pass-dead-strip(ctx: c1): c2
|> std/compiler:target-of(ctx: c2)
| zig |> std/compiler:emit-zig(ctx: c2): e
    |> std/compiler:write-artifact(e.ctx, e.code, name: "output_emitted.zig"): w
    |> std/compiler:has-flag(flag: "deep-check"): h
    |> std/compiler:branch(cond: h)
    | yes |> std/compiler:validate-emitted(w.ctx, w.code): v -> v
    | no |> std/compiler:host-build-zig(w.ctx, w.code): v -> v
| js |> std/compiler:emit-js-artifact(ctx: c2): e -> e
| cs |> std/compiler:emit-cs-artifact(ctx: c2): e -> e
| c |> std/compiler:emit-c-artifact(ctx: c2): e -> e
| other |> std/compiler:emit-zig-artifact(ctx: c2): e -> e

std/io:print.ln("routed emission")
