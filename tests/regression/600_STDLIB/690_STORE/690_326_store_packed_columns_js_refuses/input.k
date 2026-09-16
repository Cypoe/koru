// PINS: a packed store on the JS target refuses at `new`, loudly.
// `web: Server` expands to dotted columns (`web.port`), and the JS
// emitter has no lowering for them — every access would spell
// `store.web.port`, a nested-property misread of a flat column array.
// Emitting invalid JavaScript is the failure this refuses: the target
// says what it cannot do at compile time (KORU161, naming the column)
// instead of handing node a syntax error. Zig runs the same program
// fine — the pin holds both sides: green on zig, clean refusal on js.
import std/io
import std/proto
import std/store

std/proto(Server) {
    port: i64
}

std/store:new(fleet, capacity: 4) { web: Server }

std/store:insert(fleet) { web.port: 8080 }

std/store:query(fleet)
! query q |> std/io:print.ln("port {{ q.web.port:d }}")
