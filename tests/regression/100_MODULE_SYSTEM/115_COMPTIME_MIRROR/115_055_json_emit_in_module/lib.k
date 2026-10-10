// lib.k — `std/json:emit` declared and used from an imported module. The
// transform emits a per-site escaping writer specialized to the resolved
// schema; from a module the call site's bindings and the generated unit's
// qualifier both have to hold — entry-file tests cannot see either slip.
// The values emit resolves here are destructure fields from an upstream
// `std/json:parse` — a full parse→emit round trip inside the module.
import std/io
import std/json

pub tor roundtrip { body: string }
roundtrip = std/json:parse(input: body)
| malformed { message, offset } |> std/io:print.ln("mod BAD {{ offset:d }}: {{ message:s }}")
| ok { service: string, port: i64, tls: bool } |> std/json:emit(value: { service, port, tls, meta: { tier: "arena" } }): out
    |> std/io:print.ln("mod {{ out:s }}") |> std/json:emit.free(text: out)
