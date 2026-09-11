// IMPLEMENTED — the continuation must not depend on pointer identity.
//
// `advance` allocates a NEW handle and destroys the old, yet the caller here is
// identical to 336_007: `h` continues, no rebind. The caller observes only the
// base type (still a Handle) and the phantom state (now <active!>); whether the
// implementation re-tagged the old pointer or minted a fresh one is invisible,
// and therefore not something the caller should have to encode.
//
// Green: the desugar binds the freshly allocated handle to `__cont0`, and
// `close` destroys THAT pointer — not the freed one (output_emitted.zig).
import app/held
import std/io

app/held:open()
| opened h |> app/held:advance(h) |> app/held:close(h) |> std/io:print.ln("advanced (new allocation), in place")
| err e |> std/io:print.ln("err: {{ e:s }}")
