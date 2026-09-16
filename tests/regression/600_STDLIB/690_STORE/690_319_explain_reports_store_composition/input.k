// Test: `koruc explain` on a packed store — std/store's explainer folds
// the sites (new's capacity and member block, insert/query/watch counts)
// and reports the composition alongside the facet-honesty row: `Limb`
// carries a refine facet on `health`, both members declare it, and
// `std/store:insert` does NOT enforce it — the catalog says so plainly.
// post.sh drives the text rows and the typed json catalog.
import std/io
import std/proto
import std/refine
import std/store
import std/explain

std/proto:i64(Health)

std/proto(Limb) {
    health: Health
}

std/refine(Limb) {
    health: Health & >0 & <=100
}

std/store:new(body, capacity: 8) { left: Limb, right: Limb }

std/store:insert(body) { left.health: 10, right.health: 20 }

std/store:query(body)
! query e |> std/io:print.ln("left {{ e.left.health:d }}")
