// A defined flow's body is stored source, re-parsed and executed inline on
// every dispatch — and the defined-flows table is a live namespace
// (440_012), so a body that calls its own name resolves to itself: a
// self-referencing redefine recurses. run forwards no budget (metering
// parked), so the only bound is the dispatch depth cap — a runaway defined
// flow is REFUSED by name instead of overflowing the stack and killing
// the agent's process mid-turn.
//
// The cap is a depth limit, not a ban on recursion: `drain` re-invokes
// itself only while `next` answers `more`; when `next` answers `done` no
// arm matches and the run hands the outcome back — bounded recursion
// through outcome arms stays legal.
import std/io
import std/bridge
import std/runtime

tor next {}
| more string
| done string
proc next|zig {
    const S = struct { var countdown: i64 = 3; };
    if (S.countdown > 0) {
        S.countdown -= 1;
        @import("std").debug.print("tick\n", .{});
        return .{ .more = "tick" };
    }
    return .{ .done = "fin" };
}

tor emit { text: string }
| ok string
| fail string
proc emit|zig {
    @import("std").debug.print("emit: {s}\n", .{text});
    return .{ .ok = "e" };
}

std/runtime:register(scope: "rec") {
    next(1)
    emit(1)
}

tor run-it { br: *std/bridge:Bridge<session>, source: string }
run-it = std/bridge:run(br, source)
| result r |> std/io:print.ln("  result")
| unhandled-branch ub |> std/io:print.ln("  unhandled {{ ub.branch:s }}")
| defined d |> std/io:print.ln("  defined {{ d:s }}")
| dispatch-error e |> std/io:print.ln("  refused: {{ e.message:s }}")
| parse-error p |> std/io:print.ln("  parse: {{ p.message:s }}")
| validation-error v |> std/io:print.ln("  invalid: {{ v:s }}")
| event-denied ev |> std/io:print.ln("  denied {{ ev:s }}")
| residue _ |> std/io:print.ln("  residue")
| exhausted _ |> std/io:print.ln("  exhausted")
| shape-error sh |> std/io:print.ln("  shape: {{ sh.message:s }}")
| partial p |> std/io:print.ln("  partial:\n{{ p.report:s }}")
| scope-not-found s |> std/io:print.ln("  noscope {{ s:s }}")

// 1. Bounded recursion: next fires `more` three times, drain recurses on
//    each, then `done` has no arm and the run hands it back.
// 2. Self-referencing redefine: loop is redefined to call itself; the
//    self-call resolves to the NEW body — runaway — refused at the cap.
// 3. The bridge survives: an ordinary dispatch still runs after.
[with]std/bridge:create(id: "rec-cap", scope: "rec"): br
|> run-it(br, source: "tor drain {}\ndrain = next() | more m |> drain()")
|> run-it(br, source: "drain()")
|> run-it(br, source: "tor loop {}\nloop = emit(text: \"once\")")
|> run-it(br, source: "loop()")
|> run-it(br, source: "tor loop {}\nloop = loop()")
|> run-it(br, source: "loop()")
|> run-it(br, source: "emit(text: \"alive\")")
