// std/channel — `capacity: 0` is refused, loudly. Rendezvous (a send that
// parks until a consumer takes) is the deferred-resume frontier named in
// docs/CHANNEL.md — buffered channels only, so the declaration says so
// rather than silently minting a channel that can never buffer.
import std/proto
import std/channel

std/proto(Reading) {
    id: u64
    ts: f64
}

std/channel:new(bad, capacity: 0) { reading: Reading }
