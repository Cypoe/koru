// `{ policy: Name }` delegates the decision rules to a named same-module
// tor. The policy consumes the failure stream under the arm vocabulary
// (`f` = latest failure payload, `t` = retries spent — the bound channel,
// required) and produces the SAME vocabulary the arms spell:
// `| retry i64` re-enters with the payload as the child's sole input,
// `| exhausted i64` produces on the supervised branch. Here climb grants
// five re-entries (dial 8081..8085), then exhausts with 9000.
import std/io
import std/supervisor

pub tor dial { port: i64 }
| ok i64
| refused i64

proc dial|zig {
    @import("std").debug.print("dial {d}...\n", .{port});
    return .{ .refused = port };
}

pub tor climb { f: i64, t: i64 }
| retry i64
| exhausted i64

proc climb|zig {
    if (t < 5) {
        return .{ .retry = f + 1 };
    }
    return .{ .exhausted = 9000 };
}

pub tor connect { port: i64 }
| ok i64
| refused i64

connect = dial(port)
| ok p => ok p
| refused f |> std/supervisor:supervised { policy: climb }

connect(port: 8080)
| ok p |> std/io:print.ln("connected on {{ p:d }}")
| refused f |> std/io:print.ln("no service near {{ f:d }}")
