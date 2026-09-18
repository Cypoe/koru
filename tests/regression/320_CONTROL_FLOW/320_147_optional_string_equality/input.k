// Pins: `==` and `!=` on OPTIONAL strings against a literal — 320_140's
// shape with `?string` operands. The emission is presence-aware:
// null==null is true, null==value is false WITHOUT touching the payload,
// and the payload comparison only unwraps when both sides are present
// (codegen_utils.zig's comptime @typeInfo dispatch — a non-optional
// operand folds back to plain mem.eql).
import std/io

pub tor src { name: string } -> ?string
proc src|zig { return name; }

pub tor none {} -> ?string
proc none|zig { return null; }

src(name: "clip.wav"): a
|> if (a == "clip.wav")
| then |> std/io:print.ln("match")
| else |> std/io:print.ln("FAIL-match")

src(name: "other.wav"): b
|> if (b != "clip.wav")
| then |> std/io:print.ln("mismatch")
| else |> std/io:print.ln("FAIL-mismatch")

none(): c
|> if (c != "clip.wav")
| then |> std/io:print.ln("null-nomatch")
| else |> std/io:print.ln("FAIL-null")

none(): d
|> if (d == "clip.wav")
| then |> std/io:print.ln("FAIL-null-eq")
| else |> std/io:print.ln("null-false")
