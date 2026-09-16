// Test: refine enforcement on the JS target — a root-proto store's leaf
// column carries the met bounds into the generated insert's `?!violated`
// guard, `| violated f |>` supervises the breach, `| ok` answers the
// admitted insert, and the committed row queries back. LANGUAGES lists
// both targets: the same expected.txt must hold under zig and node —
// the panic-branch arm and the guard prelude are born per-target.
import std/io
import std/proto
import std/refine
import std/store

std/proto:i64(Port)

std/proto(Server) {
    port: Port
}

std/refine(Server) {
    port: Port & >1024 & <=65535
}

std/store:new(fleet, capacity: 4) { Server }

std/store:insert(fleet) { port: 80 }
| violated f |> std/io:print.ln("rejected {{ f:s }}")

std/store:insert(fleet) { port: 8080 }
| ok |> std/io:print.ln("inserted")

std/store:query(fleet)
! query q |> std/io:print.ln("port {{ q.port:d }}")
