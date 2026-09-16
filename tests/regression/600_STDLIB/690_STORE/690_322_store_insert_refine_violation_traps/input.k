// Test: an unhandled `?!violated` traps — the insert site handles no
// panic branch, so auto-discharge synthesizes the @panic arm and the
// runtime echoes the payload (the column spelling) before the trap.
// The row is never committed; the store's contract stays loud.
//
// Expected: EXPECT_TRAP — stderr matches expected_patterns (the
//           synthesized panic arm naming the event and the field).
import std/proto
import std/refine
import std/store
import std/io

std/proto:i64(Port)

std/proto(Server) {
    port: Port
}

std/refine(Server) {
    port: Port & >1024 & <=65535
}

std/store:new(fleet, capacity: 8) { web: Server }

std/store:insert(fleet) { web.port: 8080 }

std/store:insert(fleet) { web.port: 80 }
