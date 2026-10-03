// A four-turn sandbox agent: the model's wire is confined to scope-granted
// procs inside a sandbox dir; a tor it defines mid-session persists to the
// bridge world and dispatches in the same run; a `..` escape is fenced by
// the proc, not the bridge.
import std/io
import std/bridge
import std/runtime
import std/interpreter

tor ls { } -> string
proc ls|zig {
    const std = @import("std");
    var d = std.fs.cwd().openDir("tests/regression/400_RUNTIME_FEATURES/440_RESOURCE_BRIDGE/440_041_sandbox_agent/sandbox", .{.iterate = true}) catch return "<empty>";
    defer d.close();
    var out = std.ArrayList(u8){};
    var it = d.iterate();
    while (it.next() catch null) |e| out.writer(std.heap.page_allocator).print("{s}\n", .{e.name}) catch {};
    return out.items;
}
tor read { path: string } -> string
proc read|zig {
    const std = @import("std");
    if (std.mem.indexOf(u8, path, "..") != null) return "<fenced>";
    const p = std.fmt.allocPrint(std.heap.page_allocator, "tests/regression/400_RUNTIME_FEATURES/440_RESOURCE_BRIDGE/440_041_sandbox_agent/sandbox/" ++ "{s}", .{path}) catch unreachable;
    return std.fs.cwd().readFileAlloc(std.heap.page_allocator, p, 1<<20) catch "<unreadable>";
}
tor write { path: string, text: string } -> string
proc write|zig {
    const std = @import("std");
    if (std.mem.indexOf(u8, path, "..") != null) return "<fenced>";
    const p = std.fmt.allocPrint(std.heap.page_allocator, "tests/regression/400_RUNTIME_FEATURES/440_RESOURCE_BRIDGE/440_041_sandbox_agent/sandbox/" ++ "{s}", .{path}) catch unreachable;
    std.fs.cwd().writeFile(.{ .sub_path = p, .data = text }) catch return "<unwritable>";
    return "wrote";
}
// The model is a proc — this one plays a script; yours calls an API.
tor model { n: u32 } -> string
proc model|zig {
    const turns = [_][]const u8{
        "ls()",
        "tor sweep { path: string, text: string }\nsweep = write(path, text)",
        "sweep(path: \"invented.txt\", text: \"the agent wrote a verb\")",
        "write(path: \"../etc/evil\", text: \"pwn\")",
    };
    return turns[n - 1];
}

std/runtime:register(scope: "sandbox") {
    ls(1)
    read(1)
    write(1)
}

tor turn { br: *std/bridge:Bridge, n: u32 }
turn = model(n): wire
|> std/io:print.ln("  agent> {{ wire:s }}")
|> std/bridge:run(br, source: wire)
| result r |> std/interpreter:value.stringify(r.value): j |> std/io:print.ln("  world< {{ j:s }}")
| defined d |> std/io:print.ln("  world< defined {{ d:s }}")
| parse-error e |> std/io:print.ln("  world< parse: {{ e.message:s }}")
| event-denied ev |> std/io:print.ln("  world< denied: {{ ev:s }}")
| shape-error s |> std/io:print.ln("  world< shape: {{ s.branch:s }}")
| dispatch-error e |> std/io:print.ln("  world< dispatch: {{ e.message:s }}")
| validation-error _ |> std/io:print.ln("  world< validation")
| residue _ |> std/io:print.ln("  world< residue")
| exhausted _ |> std/io:print.ln("  world< exhausted")
| scope-not-found _ |> std/io:print.ln("  world< no scope")
| unhandled-branch _ |> std/io:print.ln("  world< unhandled")

[with]std/bridge:create(id: "a", scope: "sandbox", world: "tests/regression/400_RUNTIME_FEATURES/440_RESOURCE_BRIDGE/440_041_sandbox_agent/world"): br
|> turn(br, n: 1)
|> turn(br, n: 2)
|> turn(br, n: 3)
|> turn(br, n: 4)
|> std/bridge:close(br)
