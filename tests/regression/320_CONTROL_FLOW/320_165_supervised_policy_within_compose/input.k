// `within` composes with delegation: the policy grants the retry, the
// spacing veto declines it — a decline is not a policy decision, so the
// pending failure proceeds upward in kind. `within: 1 s` deterministically
// vetoes every re-entry after the first (no retry cadence outruns a
// second): dial 8081 fires, the 8082 grant is declined, `gave up 8081`.
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
| refused f |> std/supervisor:supervised { policy: climb, within: 1 s }

connect(port: 8080)
| ok p |> std/io:print.ln("connected on {{ p:d }}")
| refused f |> std/io:print.ln("no service near {{ f:d }}")
