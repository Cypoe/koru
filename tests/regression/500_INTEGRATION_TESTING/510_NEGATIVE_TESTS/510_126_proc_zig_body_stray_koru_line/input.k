// PINS: a `proc|zig` body is opaque host text, forwarded verbatim into
// output_emitted.zig — a stray Koru line inside it must not ride a green
// verdict. Under --deep-check the emission itself is witnessed: text that
// `zig ast-check` would refuse fails as error[KORU207], naming the line in
// the emitted file — not as a green "deep check passed."
//
// Found by the composition GP fuzzer (challenge 031, .kfuzz/findings_gp/
// gp_2_pass): a spliced `| ok s |> std/io:print.ln(...)` inside a called
// proc's |zig body scored PASS while the emission was unparseable Zig.
// The instrument could not distinguish "emitted" from "emitted valid";
// now it does.
import std/io

pub tor worker { n: i64 }
| ok i64
| ?!boom i64

proc worker|zig {
    return .{ .ok = n };
    | stray |> std/io:print.ln("a koru line inside host text")
}

worker(n: 1)
| ok v |> std/io:print.ln("{{ v:d }}")
| boom _ |> _
