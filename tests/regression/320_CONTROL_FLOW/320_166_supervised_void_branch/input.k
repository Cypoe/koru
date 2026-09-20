// `| refused` bare is a void branch — the failure is a fact, not a payload.
// Supervising it needs no `f` binding: `| refused |> supervised` works
// unchanged, and the retry derives the next attempt's args from ambient
// inputs (`port + 1` reads the port that just REFUSED — the step's inputs
// are the last attempt's args, so the derivation walks the range one up
// from each failure) — nothing about the keep-alive machinery requires
// the failure to carry a value.
//
// Pinned: arm mode (retry + exhausted forward), block shorthand
// (`{ restart: N }`), and `{ policy: }` delegation all honor void
// supervised branches — exhaustion forwards in kind, never binds a
// phantom payload name.
import std/io
import std/supervisor

pub tor dial { port: i64 }
| ok i64
| refused

dial = std/io:print.ln("dial {{ port:d }}...")
|> if (port == 8083)
| then => ok port
| else => refused

pub tor climb { t: i64 }
| retry i64
| exhausted

climb = if (t < 3)
| then => retry (8081 + t)
| else => exhausted

pub tor connect { port: i64 }
| ok i64
| refused

connect = dial(port)
| ok p => ok p
| refused |> std/supervisor:supervised
    | retry t when t < 5 |> dial(port: port + 1)
    | exhausted => refused

pub tor block-scan { port: i64 }
| ok i64
| refused

block-scan = dial(port)
| ok p => ok p
| refused |> std/supervisor:supervised { restart: 2 }

pub tor policy-scan { port: i64 }
| ok i64
| refused

policy-scan = dial(port)
| ok p => ok p
| refused |> std/supervisor:supervised { policy: climb }

connect(port: 8080)
| ok p |> std/io:print.ln("connected on {{ p:d }}")
| refused |> std/io:print.ln("connect gave up")

block-scan(port: 8079)
| ok p |> std/io:print.ln("block connected on {{ p:d }}")
| refused |> std/io:print.ln("block gave up")

policy-scan(port: 8080)
| ok p |> std/io:print.ln("policy connected on {{ p:d }}")
| refused |> std/io:print.ln("policy gave up")
