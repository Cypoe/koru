// PIN — `source: Source` on a runtime tor binds to an ordinary |zig proc and
// transports the captured block text. The brace-block form `render { ... }`
// captures raw text (no quote delimiters), and the tor emits at runtime —
// it is NOT implicitly comptime. Explicit [comptime]/[norun] annotations and
// `Program` params remain the only implicit-timing controls.
import std/io

tor render { source: Source } -> string
proc render|zig {
    return source.text;
}

render { hello world }: s |> std/io:print.ln("{{ s:s }}")
