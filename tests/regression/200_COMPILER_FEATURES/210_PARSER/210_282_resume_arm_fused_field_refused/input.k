// PINS: a resume arm whose record type fuses two fields on one line
// (`b: i32 c: i32`, comma dropped) refuses PARSE003 at the declaration —
// a `{`-led arm type is a field list and is validated by the one field
// parser, same as a record return or record resume. The arm-type sibling
// of 210_279's record-resume pin.
import std/io
pub tor request { payload: i32 }
! ask | halved { a: i32, b: i32 c: i32 } | timeout
| done i32

proc request|zig {
    const r = ask();
    return switch (r) {
        .halved => |v| .{ .done = v.a },
        .timeout => .{ .done = -1 },
    };
}

request(payload: 20)
! ask => halved { a: 1, b: 2, c: 3 }
| done r |> std/io:print.ln("{{ r:d }}")
