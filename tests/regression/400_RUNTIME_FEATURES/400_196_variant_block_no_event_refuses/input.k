// `dial = |zig { ... }` in flow-body position parses as a variant-tagged
// invocation with an EMPTY path — nothing to resolve. It used to panic
// upstream in keyword resolution (`path.segments[0]` on len 0); the shape
// checker now refuses first with a diagnostic that names the handler
// spelling (`proc name|zig { ... }`).
import std/io

pub tor dial { port: i64 }
| ok i64
| refused i64

dial = |zig {
    _ = port;
    return .{ .refused = port };
}

dial(port: 8080)
| ok p |> std/io:print.ln("ok {{ p:d }}")
| refused f |> std/io:print.ln("refused {{ f:d }}")
