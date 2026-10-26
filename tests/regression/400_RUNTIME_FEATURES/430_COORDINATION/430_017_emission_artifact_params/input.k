// Test 430_017: the materialization tors take optional params —
// `dir:` relocates the emitted artifact, `output:` names the binary.
//
// Twin of 430_016 (routed emission override). The zig arm re-spells the
// default chain with params bound: write-artifact stages
// output_emitted.zig under stage/ instead of cwd, and host-build-zig
// reads it back from there and names the produced binary `output` —
// the same name argv would have given it, proving the param IS the
// naming surface rather than a second channel. If `dir` plumbing broke
// either direction — the artifact written to cwd, or the build reading
// cwd — the chain dies: stage/ holds the only copy (post.sh asserts
// both directions).

import std/compiler
import std/io

std/compiler:emission = std/compiler:inject-ccp(ctx): c1
|> std/compiler:pass-dead-strip(ctx: c1): c2
|> std/compiler:target-of(ctx: c2)
| zig |> std/compiler:emit-zig(ctx: c2): e
    |> std/compiler:write-artifact(e.ctx, e.code, name: "output_emitted.zig", dir: "stage"): w
    |> std/compiler:has-flag(flag: "deep-check"): h
    |> std/compiler:branch(cond: h)
    | yes |> std/compiler:validate-emitted(w.ctx, w.code): v -> v
    | no |> std/compiler:host-build-zig(w.ctx, w.code, output: "output", dir: "stage"): v -> v
| js |> std/compiler:emit-js-artifact(ctx: c2): e -> e
| cs |> std/compiler:emit-cs-artifact(ctx: c2): e -> e
| c |> std/compiler:emit-c-artifact(ctx: c2): e -> e
| other |> std/compiler:emit-zig-artifact(ctx: c2): e -> e

std/io:print.ln("param emission")
