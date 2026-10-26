// An agent, two sessions, one world: session A does a file-copy by hand,
// invents `backup`, and session B's vocabulary already contains it.
// The world also holds the custody record — A mints a handle, borrows
// it (`use`), discharges it; B's `custody()` reads A's settled span,
// and B's borrow of the released handle is refused, leaving no event.
import std/io
import std/bridge
import std/runtime
import std/interpreter

tor read { path: string } -> string
proc read|zig {
    const std = @import("std");
    if (std.mem.indexOf(u8, path, "..") != null) return "<fenced>";
    const p = std.fmt.allocPrint(std.heap.page_allocator, "tests/regression/400_RUNTIME_FEATURES/440_RESOURCE_BRIDGE/440_043_two_sessions_one_world/files/{s}", .{path}) catch unreachable;
    return std.fs.cwd().readFileAlloc(std.heap.page_allocator, p, 1 << 20) catch "<unreadable>";
}
tor write { path: string, text: string } -> string
proc write|zig {
    const std = @import("std");
    if (std.mem.indexOf(u8, path, "..") != null) return "<fenced>";
    const p = std.fmt.allocPrint(std.heap.page_allocator, "tests/regression/400_RUNTIME_FEATURES/440_RESOURCE_BRIDGE/440_043_two_sessions_one_world/files/{s}", .{path}) catch unreachable;
    std.fs.cwd().writeFile(.{ .sub_path = p, .data = text }) catch return "<unwritable>";
    return "wrote";
}

tor open { path: string } -> string<opened!>
proc open|zig {
    _ = path;
    return "conn_1";
}
tor poke { conn: string<opened> } -> string
proc poke|zig {
    _ = conn;
    return "poked";
}
tor shut { conn: string<!opened> } -> string
proc shut|zig {
    _ = conn;
    return "closed";
}

std/runtime:register(scope: "sandbox") {
    read(1)
    write(1)
    open(1)
    poke(1)
    shut(1)
}

tor turn { br: *std/bridge:Bridge<session>, source: string }
turn = std/io:print.ln("  agent> {{ source:s }}")
|> std/bridge:run(br, source)
| result r |> std/interpreter:value.stringify(r.value): j |> std/io:print.ln("  world< {{ j:s }}")
| defined d |> std/io:print.ln("  world< defined {{ d:s }}")
| error runerr |> std/bridge:error-decode(e: runerr)
    | parse-error e |> std/io:print.ln("  world< parse: {{ e.message:s }}")
    | event-denied ev |> std/io:print.ln("  world< denied: {{ ev:s }}")
    | shape-error s |> std/io:print.ln("  world< shape: {{ s.branch:s }}")
    | dispatch-error e |> std/io:print.ln("  world< dispatch: {{ e.message:s }}")
    | validation-error _ |> std/io:print.ln("  world< validation")
    | exhausted _ |> std/io:print.ln("  world< exhausted")
    | scope-not-found _ |> std/io:print.ln("  world< no scope")
| residue _ |> std/io:print.ln("  world< residue")
| unhandled-branch _ |> std/io:print.ln("  world< unhandled")

[with]std/bridge:create(id: "a", scope: "sandbox", introspection: true, world: "tests/regression/400_RUNTIME_FEATURES/440_RESOURCE_BRIDGE/440_043_two_sessions_one_world/world"): a
|> turn(br: a, source: "read(path: \"hello.txt\")\n| ok t |> write(path: \"backup.txt\", text: t)")
|> turn(br: a, source: "tor backup { src: string, dst: string }\nbackup = read(path: src)\n| ok t |> write(path: dst, text: t)")
|> turn(br: a, source: "backup(src: \"hello.txt\", dst: \"again.txt\")")
|> turn(br: a, source: "open(path: \"hello.txt\")")
|> turn(br: a, source: "poke(conn: \"conn_1\")")
|> turn(br: a, source: "custody()")
|> turn(br: a, source: "shut(conn: \"conn_1\")")
|> std/bridge:close(br: a)
|> std/bridge:create(id: "b", scope: "sandbox", introspection: true, world: "tests/regression/400_RUNTIME_FEATURES/440_RESOURCE_BRIDGE/440_043_two_sessions_one_world/world"): b
|> turn(br: b, source: "vocabulary()")
|> turn(br: b, source: "poke(conn: \"conn_1\")")
|> turn(br: b, source: "custody()")
|> turn(br: b, source: "backup(src: \"hello.txt\", dst: \"b-copy.txt\")")
|> turn(br: b, source: "format-disk()")
|> std/bridge:close(br: b)
