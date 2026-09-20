// Refusal pin: `| ok p` where the producer declares `| ok` void.
// Supervision passes branch shapes through the fold verbatim — a void
// branch declares nothing, so there is nothing to bind. The binding
// refuses with KORU101 exactly as it would without `supervised`.
import std/io
import std/supervisor

pub tor dial { port: i64 }
| ok
| refused

dial = std/io:print.ln("dial {{ port:d }}...")
|> if (port < 8083)
| then => refused
| else => ok

pub tor connect { port: i64 }
| ok i64
| refused

connect = dial(port)
| ok p => ok p
| refused |> std/supervisor:supervised
    | retry t when t < 5 |> dial(port: port + 1)

connect(port: 8080)
| ok p |> std/io:print.ln("connected on {{ p:d }}")
| refused |> std/io:print.ln("no service in range")
