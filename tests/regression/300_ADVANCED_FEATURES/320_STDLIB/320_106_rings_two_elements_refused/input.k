// std/rings — one ring holds one element shape. A second named entry
// isn't an element, it's a second lane — and the refusal says so by
// name: more than one kind is a channel.
import std/rings

std/rings:new(q, capacity: 4) { a: u64, b: u64 }
