// The world seam: `create(world: <dir>)` mounts a directory of flow files
// as the session's starting vocabulary, and every define that lands writes
// `<dir>/<name>.k` — so session N+1 inherits what session N invented.
//
// Session `a` defines `greet` and closes. Session `b` creates against the
// same world dir — `greet` is already vocabulary and dispatches without a
// fresh define. The file itself is verbatim definition source (post.sh
// pins `world/greet.k`), so the directory reads and gardens like a
// program. Vocabulary persists; possession does not — the pool mints
// empty either way.
import std/io
import std/bridge
import std/runtime
import std/interpreter

tor echo { text: string } -> string
proc echo|zig {
    const std = @import("std");
    return std.fmt.allocPrint(std.heap.page_allocator, "echo:{s}", .{text}) catch unreachable;
}

std/runtime:register(scope: "api") {
    echo(1)
}

tor do-define { br: *std/bridge:Bridge<session>, source: string }
do-define = std/bridge:define(br, source)
| defined d |> std/io:print.ln("  defined {{ d:s }}")
| parse-error e |> std/io:print.ln("  define FAILED {{ e.message:s }}")

tor run-greet { br: *std/bridge:Bridge<session> }
run-greet = std/bridge:run(br, source: "greet(text: \"hi\")")
| result r |> std/interpreter:value.stringify(r.value): j |> std/io:print.ln("  greet -> {{ j:s }}")
| parse-error e |> std/io:print.ln("  greet PARSE {{ e.message:s }}")
| event-denied ev |> std/io:print.ln("  greet DENIED {{ ev:s }}")
| dispatch-error e |> std/io:print.ln("  greet DISPATCH {{ e.message:s }}")
| shape-error s |> std/io:print.ln("  greet SHAPE {{ s.branch:s }}")
| validation-error _ |> std/io:print.ln("  greet VALIDATION")
| residue _ |> std/io:print.ln("  greet RESIDUE")
| exhausted _ |> std/io:print.ln("  greet EXHAUSTED")
| scope-not-found _ |> std/io:print.ln("  greet NOSCOPE")
| defined d |> std/io:print.ln("  greet DEFINED {{ d:s }}")
| unhandled-branch _ |> std/io:print.ln("  greet UNHANDLED")

[with]std/bridge:create(id: "s1", scope: "api", world: "tests/regression/400_RUNTIME_FEATURES/440_RESOURCE_BRIDGE/440_040_world_define_persists_across_sessions/world"): a
|> std/io:print.ln("--- session a open")
|> do-define(br: a, source: "tor greet { text: string }\ngreet = echo(text)")
|> std/bridge:close(br: a)
|> std/io:print.ln("--- session a closed")
|> std/bridge:create(id: "s2", scope: "api", world: "tests/regression/400_RUNTIME_FEATURES/440_RESOURCE_BRIDGE/440_040_world_define_persists_across_sessions/world"): b
|> std/io:print.ln("--- session b open")
|> run-greet(br: b)
|> std/bridge:close(br: b)
|> std/io:print.ln("--- session b closed")
