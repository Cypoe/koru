// Pins: a bare wire value is a Koru expression — `calc(expr: 2 + 3)`
// evaluates to i64 5 through the dispatcher; a `string` field arrives as
// the quoted literal's text. The gate admits expression text whole and
// the evaluator judges it — there is no capture channel: declared field
// type, not value shape, is the contract.
//
// These are runtime fields — [comptime], [norun], and Program remain the
// only timing controls (400_202/400_203 pin the emitted-backend twin).
import std/io
import std/bridge
import std/runtime

tor calc { expr: i64 }
proc calc|zig {
    _ = @import("std").posix.write(1, "calc:") catch {};
    const buf = @import("std").fmt.allocPrint(@import("std").heap.page_allocator, "{d}", .{expr}) catch unreachable;
    _ = @import("std").posix.write(1, buf) catch {};
    _ = @import("std").posix.write(1, "\n") catch {};
}

tor render { src: string }
proc render|zig {
    _ = @import("std").posix.write(1, "render:") catch {};
    _ = @import("std").posix.write(1, src) catch {};
    _ = @import("std").posix.write(1, "\n") catch {};
}

std/runtime:register(scope: "api") {
    calc(1)
    render(1)
}

tor gated { br: *std/bridge:Bridge<session> }
gated = std/bridge:run(br, source: "calc(expr: 2 + 3)\nrender(src: \"hello world\")")
| partial p |> std/io:print.ln("{{ p.report:s }}")
| result r |> std/io:print.ln("FAIL result — a two-item turn reports per step")
| unhandled-branch ub |> std/io:print.ln("FAIL unhandled {{ ub.branch:s }}")
| error runerr |> std/bridge:error-decode(e: runerr)
    | event-denied ev |> std/io:print.ln("FAIL denied {{ ev:s }}")
    | parse-error p |> std/io:print.ln("FAIL parse {{ p.message:s }}")
    | validation-error v |> std/io:print.ln("FAIL invalid {{ v:s }}")
    | shape-error sh |> std/io:print.ln("FAIL shape {{ sh.message:s }}")
    | dispatch-error e |> std/io:print.ln("FAIL dispatch {{ e.message:s }}")
    | exhausted _ |> std/io:print.ln("FAIL exhausted")
    | scope-not-found s2 |> std/io:print.ln("FAIL noscope {{ s2:s }}")
| residue _ |> std/io:print.ln("FAIL: residue outcome")
| defined d |> std/io:print.ln("FAIL defined {{ d:s }}")

[with]std/bridge:create(id: "cap", scope: "api"): br
|> gated(br)
