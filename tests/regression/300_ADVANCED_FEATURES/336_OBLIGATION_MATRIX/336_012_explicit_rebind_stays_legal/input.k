// RULING GUARD (2026-09-11): the explicit rebind stays legal.
//
// The advance removes the COMPULSION to rebind; it does not forbid the rebind.
// `advance(h): h2 |> close(h: h2)` names the re-minted handle and is still the
// conservative, no-shadowing-respecting spelling. A future narrowing that
// refuses it — e.g. a KORU115-style retirement of the unambiguous rebind — must
// break this pin. See concepts/frag-a-consumed-handle-should-continue-its-binding.
import app/held
import std/io

app/held:open()
| opened h |> app/held:advance(h): h2 |> app/held:close(h: h2) |> std/io:print.ln("explicit rebind, in place")
| err e |> std/io:print.ln("err: {{ e:s }}")
