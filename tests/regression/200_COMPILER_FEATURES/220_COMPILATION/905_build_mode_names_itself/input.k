// PINS: the success line names the output binary's build mode. The Debug
// default is deliberate — bounds/overflow/unreachable checks stay on so
// the suite judges safe code — but it was INVISIBLE: `koruc prog.k`
// produced a bounds-checked binary and said nothing, which is how a
// benchmark ends up timing Debug output. post.sh greps backend.out for
// `Compiled to output (Debug)` — the banner, not the binary.
import std/io

std/io:print.ln("ok")
