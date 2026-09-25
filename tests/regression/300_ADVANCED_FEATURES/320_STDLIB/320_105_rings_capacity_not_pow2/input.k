// std/rings — capacity must be a power of two: the Vyukov ring masks
// with cap-1. A non-power-of-two capacity refuses at the declaration.
import std/rings

std/rings:new(q, capacity: 3) { value: u64 }
