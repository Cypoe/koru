// std/rings — a phantom-typed element value is refused at the declaration:
// `Src<live!>` carries custody that a slot can't hold this rung. Twin of
// 320_109 (borrow element); the obligation-transit rung (699_022 family)
// decides whether this refusal relaxes into consume/mint semantics or stays
// a wall by design.
import std/proto
import std/rings

std/proto(Src) {
    id: i64
}

std/rings:new(feed, capacity: 8) { value: Src<live!> }
