// Test: `koruc explain` reports the store's facet verdict — the
// `facets_declared` row now names enforcement instead of reporting the
// gap. post.sh drives the text catalog: `insert enforces them` names the
// `?!violated` contract the generated events carry.
import std/proto
import std/refine
import std/store
import std/io
import std/explain

std/proto:i64(Port)

std/proto(Server) {
    port: Port
    weight: i64
}

std/refine(Server) {
    port: Port & >1024 & <=65535
    weight: i64
}

std/store:new(fleet, capacity: 8) { web: Server }

std/store:insert(fleet) { web.port: 8080, web.weight: 5 }
