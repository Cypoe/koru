// Pins: --lang=<tag> must name a registered emitter or a proc variant
// declared in this program — anything else is refused, not compiled.
//
// Before the guard, `koruc input.k --lang=cs` compiled a program like
// this one to a working Zig executable: every lang other than `js`
// collapsed to the Zig emitter and Stage D, so a foreign or typo'd tag
// produced a binary under a name that selected nothing. The admitted
// set is emitters (zig, js) ∪ declared proc targets (full and base),
// so `--lang=mlir` stays legal where a `|mlir` body exists and
// `--lang=raw_posix` selects the stdlib variant family by design.
import std/io

std/io:print.ln("should not get here")
