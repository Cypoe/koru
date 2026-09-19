// `{ policy: missing }` refuses at compile time — the policy must be a
// named tor in this module, consuming `{ f: <payload>, t: i64 }` and
// producing `| retry | exhausted`.
import std/supervisor

pub tor dial { port: i64 }
| ok i64
| refused i64

proc dial|zig {
    return .{ .refused = port };
}

pub tor connect { port: i64 }
| ok i64
| refused i64

connect = dial(port)
| ok p => ok p
| refused f |> std/supervisor:supervised { policy: missing }

connect(port: 8080)
