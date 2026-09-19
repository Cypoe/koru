// A delegated policy must take `t: i64` — the retry counter is the bound
// the compiler cannot see inside the tor. Arm mode reads the escape in
// the `when`; delegation's only visible bound channel is `t` itself.
// A policy without it is refused, keep-alive contract intact.
import std/supervisor

pub tor dial { port: i64 }
| ok i64
| refused i64

proc dial|zig {
    return .{ .refused = port };
}

pub tor blind { f: i64 }
| retry i64
| exhausted

proc blind|zig {
    return .{ .retry = f + 1 };
}

pub tor connect { port: i64 }
| ok i64
| refused i64

connect = dial(port)
| ok p => ok p
| refused f |> std/supervisor:supervised { policy: blind }

connect(port: 8080)
