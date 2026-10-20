// A seven-turn sandbox agent: the model's wire is confined to scope-granted
// std/fs verbs on a *Dir capability — the sandbox IS the handle, minted by
// fs:dir and fenced inside std/fs (the `..` escape is refused by the verb,
// not by a check the model could skip). A tor it defines mid-session
// persists to the bridge world and dispatches in the same run. collect-lines
// returns the ! line stream as a []string field — the wire-visible array.
import std/io
import std/bridge
import std/runtime
import std/interpreter
import std/fs

// The model is a proc — this one plays a script; yours calls an API.
tor model { n: u32 } -> string
proc model|zig {
    const turns = [_][]const u8{
        "dir(path: \"tests/regression/400_RUNTIME_FEATURES/440_RESOURCE_BRIDGE/440_041_sandbox_agent/sandbox\")\n| opened d |>",
        "list(d: r1)\n| entries e |>",
        "tor sweep { d: string, path: string, text: string } | written | failed string\nsweep = write(d, path, content: text)",
        "sweep(d: r1, path: \"invented.txt\", text: \"the agent wrote a verb\")\n| written _ |>",
        "collect-lines(d: r1, path: \"invented.txt\")\n| lines ls |>",
        "write(d: r1, path: \"../etc/evil\", content: \"pwn\")\n| written _ |>\n| failed e |>",
        "close(d: r1)",
    };
    return turns[n - 1];
}

std/runtime:register(scope: "sandbox") {
    std.fs:dir -> dir(1)
    std.fs:list -> list(1)
    std.fs:read -> read(1)
    std.fs:write -> write(1)
    std.fs:collect-lines -> collect-lines(1)
    std.fs:close -> close(1)
}

tor turn { br: *std/bridge:Bridge<session>, n: u32 }
turn = model(n): wire
|> std/io:print.ln("  agent> {{ wire:s }}")
|> std/bridge:run(br, source: wire)
| result r |> std/interpreter:value.stringify(r.value): j |> std/io:print.ln("  world< {{ j:s }}")
| defined d |> std/io:print.ln("  world< defined {{ d:s }}")
| parse-error e |> std/io:print.ln("  world< parse: {{ e.message:s }}")
| event-denied ev |> std/io:print.ln("  world< denied: {{ ev:s }}")
| shape-error s |> std/io:print.ln("  world< shape: {{ s.branch:s }}")
| dispatch-error e |> std/io:print.ln("  world< dispatch: {{ e.message:s }}")
| validation-error v |> std/io:print.ln("  world< validation {{ v:s }}")
| residue _ |> std/io:print.ln("  world< residue")
| exhausted _ |> std/io:print.ln("  world< exhausted")
| scope-not-found _ |> std/io:print.ln("  world< no scope")
| unhandled-branch u |> std/io:print.ln("  world< unhandled {{ u.branch:s }}")

[with]std/bridge:create(id: "a", scope: "sandbox", world: "tests/regression/400_RUNTIME_FEATURES/440_RESOURCE_BRIDGE/440_041_sandbox_agent/world"): br
|> turn(br, n: 1)
|> turn(br, n: 2)
|> turn(br, n: 3)
|> turn(br, n: 4)
|> turn(br, n: 5)
|> turn(br, n: 6)
|> turn(br, n: 7)
|> std/bridge:close(br)
