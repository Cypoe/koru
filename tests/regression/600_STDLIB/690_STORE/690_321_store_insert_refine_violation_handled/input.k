// Test: a store column that expands a refined proto field is judged at
// insert — `std/refine(Server) { port: Port & >1024 }` becomes a
// `?!violated` guard on the generated insert events (the same `metFields`
// fold the explainer reports). `web.port: 80` produces into the branch
// carrying the column spelling, and the caller HANDLES it
// (`| violated f |>`) instead of trapping.
//
// Expected: runs clean — `committed` for the valid row, `rejected web.port`
//           for the breach, and the query reads back only the committed row
//           (the refused insert never wrote).
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
| row r |> std/io:print.ln("committed {{ r:d }}")

std/store:insert(fleet) { web.port: 80 }
| violated f |> std/io:print.ln("rejected {{ f:s }}")

std/store:query(fleet)
! query e |> std/io:print.ln("web.port {{ e.web.port:d }}")
