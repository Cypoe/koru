// ASPIRATIONAL — `[with(mod, …)]` on a subflow impl declares the flow's open
// vocabulary EXPLICITLY: the annotation's argument list names module paths
// exactly as `import` spells them. `ping` lives only in app/alpha, `pong` only
// in app/beta — both bare, and the impl's head call resolves through the same
// declared set, so the open set is readable in one place instead of being
// scattered across whichever calls happened to carry tags.
import std/io
import app/alpha
import app/beta

tor start {}
[with(app/alpha, app/beta)]start = ping(msg: "seed"): s |> pong(msg: s): t |> std/io:print.ln("resolved={{ t:s }}")

start()
