// `koruc explain` on a supervised site — std/supervisor's explainer folds
// the site and reports what the declaration hides: the producing call the
// transform retargets, the child's declared vocabulary verbatim (both
// branches void — nothing rides them), the generated step tor + `#`/`@`
// fold the site becomes, the policy it read, and which names the re-entry
// expression resolves in the generated step's scope. The `elaborated`
// section runs the real transform on a clone and prints the generated
// items through the canonical AST printer — the explain view cannot drift
// from what the transform writes because it ran it.
// post.sh drives the text rows and the witness-hash resolution.
import std/io
import std/explain
import std/supervisor

pub tor dial { port: i64 }
| ok
| refused

dial = std/io:print.ln("dial {{ port:d }}...")
|> if (port < 8083)
| then => refused
| else => ok

pub tor connect { port: i64 }
| ok
| refused

connect = dial(port)
| ok => ok
| refused |> std/supervisor:supervised
    | retry t when t < 5 |> dial(port: port + 1)

connect(port: 8080)
| ok |> std/io:print.ln("connected")
| refused |> std/io:print.ln("no service in range")
