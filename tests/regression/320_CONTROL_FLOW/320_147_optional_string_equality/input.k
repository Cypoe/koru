// Pins: `==` and `!=` on OPTIONAL strings and on identifier-vs-identifier
// pairs — 320_140's shape with `?string` and two runtime operands. The
// emission is presence-aware (null==null true, null==value false without
// touching the payload) and type-dispatched at comptime: u8 strings take
// mem.eql, everything else folds back to `==` — the rewrite has no type
// oracle, so the emitted Zig interrogates @typeInfo itself.
import std/io

pub tor src { name: string } -> ?string
proc src|zig { return name; }

pub tor none {} -> ?string
proc none|zig { return null; }

pub tor word { w: string } -> string
proc word|zig { return w; }

pub tor num { n: i64 } -> i64
proc num|zig { return n; }

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

word(w: "x"): s1
|> word(w: "x"): s2
|> if (s1 == s2)
| then |> std/io:print.ln("ident-eq")
| else |> std/io:print.ln("FAIL-ident-eq")

word(w: "x"): s3
|> word(w: "y"): s4
|> if (s3 != s4)
| then |> std/io:print.ln("ident-ne")
| else |> std/io:print.ln("FAIL-ident-ne")

num(n: 3): n1
|> num(n: 3): n2
|> if (n1 == n2)
| then |> std/io:print.ln("int-eq")
| else |> std/io:print.ln("FAIL-int-eq")

src(name: "x"): o1
|> word(w: "x"): s5
|> if (o1 == s5)
| then |> std/io:print.ln("opt-str-eq")
| else |> std/io:print.ln("FAIL-opt-str")

src(name: "clip.wav"): e
|> if (e.? == "clip.wav" and e == "clip.wav")
| then |> std/io:print.ln("unwrap-eq")
| else |> std/io:print.ln("FAIL-unwrap")
