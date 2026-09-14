// Pins: a phantom in a BRANCH payload books one obligation for the branch
// that FIRED — not one per phantom-carrying branch in the declaration.
//
// `post` consumes <!open> and re-issues <open!> on both outcomes. The
// registry emitted one CreateSpec per branch payload and the interpreter's
// acquire loop ran them all, so every `post` booked a phantom record for a
// branch that never happened. Two posts left three undischarged records for
// one handle, and the session's hang-up dispatched the releaser once per
// phantom record — a releaser firing on a handle the world already let go.
//
// (kopium wired hole 7 — headless/ledger.kz `post` is this shape.)
import std/io
import std/bridge
import std/runtime

tor open { path: string } -> string<open!>
proc open|zig {
    _ = path;
    return "res_1";
}

tor post { handle: string<!open>, amount: string }
| ok string<open!>
| bad-amount string<open!>
proc post|zig {
    if (@import("std").mem.eql(u8, amount, "bad")) {
        return .{ .bad_amount = handle };
    }
    return .{ .ok = handle };
}

tor close { handle: string<!open> }
proc close|zig {
    @import("std").debug.print("close() ran — released '{s}'\n", .{handle});
}

tor echo { text: string }
proc echo|zig {
    _ = @import("std").posix.write(1, text) catch {};
    _ = @import("std").posix.write(1, "\n") catch {};
}

std/runtime:register(scope: "res") {
    open(10)
    post(1)
    close(1)
    echo(1)
}

// Turn 1: mint. One handle held.
tor open-turn { br: *std/bridge:Bridge }
open-turn = std/bridge:run(br, source: "open(path: \"x\")")
| result r |> std/io:print.ln("after open, holds {{ r.handles:d }}")
| unhandled-branch ub |> std/io:print.ln("FAIL turn1 unhandled {{ ub.branch:s }}")
| event-denied ev |> std/io:print.ln("FAIL turn1 denied {{ ev:s }}")
| parse-error p |> std/io:print.ln("FAIL turn1 parse {{ p.message:s }}")
| validation-error v |> std/io:print.ln("FAIL turn1 invalid {{ v:s }}")
| shape-error sh |> std/io:print.ln("FAIL turn1 shape {{ sh.message:s }}")
| dispatch-error e |> std/io:print.ln("FAIL turn1 dispatch {{ e.message:s }}")
| defined d |> std/io:print.ln("FAIL turn1 defined {{ d:s }}")
| exhausted _ |> std/io:print.ln("FAIL turn1 exhausted")
| partial p |> std/io:print.ln("FAIL turn1 partial")
| scope-not-found s2 |> std/io:print.ln("FAIL turn1 noscope {{ s2:s }}")

// Turn 2: `ok` fires — the re-issue nets zero; the pool still holds one.
tor post-ok { br: *std/bridge:Bridge }
post-ok = std/bridge:run(br, source: "post(handle: \"res_1\", amount: \"5\")\n| ok h |> echo(text: \"posted\")\n| bad-amount b |> echo(text: \"bad\")")
| result r |> std/io:print.ln("after post-ok, holds {{ r.handles:d }}")
| unhandled-branch ub |> std/io:print.ln("FAIL turn2 unhandled {{ ub.branch:s }}")
| event-denied ev |> std/io:print.ln("FAIL turn2 denied {{ ev:s }}")
| parse-error p |> std/io:print.ln("FAIL turn2 parse {{ p.message:s }}")
| validation-error v |> std/io:print.ln("FAIL turn2 invalid {{ v:s }}")
| shape-error sh |> std/io:print.ln("FAIL turn2 shape {{ sh.message:s }}")
| dispatch-error e |> std/io:print.ln("FAIL turn2 dispatch {{ e.message:s }}")
| defined d |> std/io:print.ln("FAIL turn2 defined {{ d:s }}")
| exhausted _ |> std/io:print.ln("FAIL turn2 exhausted")
| partial p |> std/io:print.ln("FAIL turn2 partial")
| scope-not-found s2 |> std/io:print.ln("FAIL turn2 noscope {{ s2:s }}")

// Turn 3: `bad-amount` fires — its OWN spec acquires (kebab in the source,
// snake in the dispatch tag), the `ok` spec stays dormant. Still one held.
tor post-bad { br: *std/bridge:Bridge }
post-bad = std/bridge:run(br, source: "post(handle: \"res_1\", amount: \"bad\")\n| ok h |> echo(text: \"posted\")\n| bad-amount b |> echo(text: \"bad\")")
| result r |> std/io:print.ln("after post-bad, holds {{ r.handles:d }}")
| unhandled-branch ub |> std/io:print.ln("FAIL turn3 unhandled {{ ub.branch:s }}")
| event-denied ev |> std/io:print.ln("FAIL turn3 denied {{ ev:s }}")
| parse-error p |> std/io:print.ln("FAIL turn3 parse {{ p.message:s }}")
| validation-error v |> std/io:print.ln("FAIL turn3 invalid {{ v:s }}")
| shape-error sh |> std/io:print.ln("FAIL turn3 shape {{ sh.message:s }}")
| dispatch-error e |> std/io:print.ln("FAIL turn3 dispatch {{ e.message:s }}")
| defined d |> std/io:print.ln("FAIL turn3 defined {{ d:s }}")
| exhausted _ |> std/io:print.ln("FAIL turn3 exhausted")
| partial p |> std/io:print.ln("FAIL turn3 partial")
| scope-not-found s2 |> std/io:print.ln("FAIL turn3 noscope {{ s2:s }}")

// One handle is held; hang-up must release it exactly once.
[with]std/bridge:create(id: "b1", scope: "res"): br
|> open-turn(br)
|> post-ok(br)
|> post-bad(br)
