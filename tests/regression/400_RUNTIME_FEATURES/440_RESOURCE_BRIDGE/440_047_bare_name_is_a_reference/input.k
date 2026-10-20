// Pins: a bare wire value obeys the bound-name law on every field — a
// lone bare token is a reference, not literal text.
//
// `sink(src: r1.flights)` resolves the bound field's text (JSON bytes
// intact), `calc(expr: r1.count)` resolves a bound scalar into an i64,
// an unbound name refuses at validation naming the arm that would bind
// it, and bare prose never parses as a value — it is not a Koru
// expression.

import std/io
import std/bridge
import std/runtime

tor produce {} -> string
proc produce|zig {
    const std = @import("std");
    const S = struct { threadlocal var buf: [256]u8 = undefined; };
    return std.fmt.bufPrint(&S.buf, "{{\"flights\": [{{\"flight_number\": \"H1001\", \"date\": \"2024-05-01\"}}], \"text\": \"payload-7\", \"count\": 7}}", .{}) catch unreachable;
}

tor sink { src: string }
proc sink|zig {
    _ = @import("std").posix.write(1, "sink:") catch {};
    _ = @import("std").posix.write(1, src) catch {};
    _ = @import("std").posix.write(1, "\n") catch {};
}

tor calc { expr: i64 }
proc calc|zig {
    _ = @import("std").posix.write(1, "calc:") catch {};
    const buf = @import("std").fmt.allocPrint(@import("std").heap.page_allocator, "{d}", .{expr}) catch unreachable;
    _ = @import("std").posix.write(1, buf) catch {};
    _ = @import("std").posix.write(1, "\n") catch {};
}

std/runtime:register(scope: "api") {
    produce(1)
    sink(1)
    calc(1)
}

tor turn { br: *std/bridge:Bridge<session>, src: string }
turn = std/bridge:run(br, source: src)
| result r |> std/io:print.ln("RESULT bound={{ r.bound:s }}")
| partial p |> std/io:print.ln("FAIL partial {{ p.report:s }}")
| unhandled-branch ub |> std/io:print.ln("FAIL unhandled {{ ub.branch:s }}")
| error runerr |> std/bridge:error-decode(e: runerr)
    | event-denied ev |> std/io:print.ln("FAIL denied {{ ev:s }}")
    | parse-error p |> std/io:print.ln("REFUSED parse {{ p.message:s }}")
    | validation-error v |> std/io:print.ln("REFUSED {{ v:s }}")
    | shape-error sh |> std/io:print.ln("FAIL shape {{ sh.message:s }}")
    | dispatch-error e |> std/io:print.ln("FAIL dispatch {{ e.message:s }}")
    | exhausted _ |> std/io:print.ln("FAIL exhausted")
    | scope-not-found s2 |> std/io:print.ln("FAIL noscope {{ s2:s }}")
| residue _ |> std/io:print.ln("FAIL: residue outcome")
| defined d |> std/io:print.ln("FAIL defined {{ d:s }}")

[with]std/bridge:create(id: "cap", scope: "api"): br
|> turn(br, src: "produce()")
|> turn(br, src: "sink(src: r1.flights)")
|> turn(br, src: "sink(src: r1.text)")
|> turn(br, src: "calc(expr: r1.count)")
|> turn(br, src: "calc(expr: r1.count + 1)")
|> turn(br, src: "calc(expr: ghost - 1)")
|> turn(br, src: "sink(src: ghost.field)")
|> turn(br, src: "sink(src: \"hello world\")")
