// std/channel — capacity is a named declaration argument, required. A
// channel is sized at the declaration; omitting `capacity:` refuses with
// the shape.
import std/proto
import std/channel

std/proto(Reading) {
    id: u64
}

std/channel:new(inbox) { reading: Reading }
