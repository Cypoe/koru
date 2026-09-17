// Test: the equality atom reaches the SECOND consumer — `std/store` builds
// its insert guard through its own path (`store.new.kz`, not
// `facets.guardBody`), so an equality enforced at `push` is no evidence it
// is enforced at `insert`. `web.port: 8080` commits; `web.port: 80`
// produces into the branch carrying the column spelling.
//
// Expected: runs clean — `committed` then `rejected web.port`.
import std/proto
import std/refine
import std/store
import std/io

std/proto:i64(Port)

std/proto(Server) {
    port: Port
}

std/refine(Server) {
    port: Port & ==8080
}

std/store:new(fleet, capacity: 4) { web: Server }

std/store:insert(fleet) { web.port: 8080 }
| row r |> std/io:print.ln("committed")

std/store:insert(fleet) { web.port: 80 }
| violated f |> std/io:print.ln("rejected {{ f:s }}")
