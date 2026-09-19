// The allowed path of `[within: N unit]` — a child slower than the
// spacing window re-enters every time. `within: 10 ms` under a worker
// that sleeps 15 ms: each restart is provably ≥15 ms after the last, so
// `t < 3` grants all three re-entries (four "try" lines) and exhaustion
// still forwards in kind. Real time, no clock double — `Thread.sleep`
// is a floor, so the inter-restart gap cannot shrink below the window
// on any machine.
import std/io
import std/supervisor

pub tor worker { n: i64 }
| ok i64
| ?!boom i64

proc worker|zig {
    @import("std").debug.print("try {d}\n", .{n});
    @import("std").Thread.sleep(15 * @import("std").time.ns_per_ms);
    return .{ .boom = n };
}

pub tor sup { n: i64 }
| ok i64
| ?!boom i64

sup = worker(n)
| ok v => ok v
| boom f |> std/supervisor:supervised
    | [within: 10 ms]
    | retry t when t < 3

sup(n: -10)
| ok r |> std/io:print.ln("got {{ r:d }}")
| boom f |> std/io:print.ln("gave up {{ f:d }}")
