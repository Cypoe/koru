// std/rings — a ring slot holds plain values by copy. A borrowed
// element (`*T`) has no slot shape this rung; the declaration refuses.
import std/proto
import std/rings

std/proto(Reading) {
    id: u64
}

std/rings:new(q, capacity: 4) { value: *Reading }
