// std/channel v1 — capacity 0 is refused, loudly. Rendezvous (a send that
// parks until a consumer takes) is the deferred-resume frontier named in
// docs/CHANNEL.md — v1 is buffered only, so the declaration says so rather
// than silently minting a channel that can never buffer.
import std/proto
import std/channel

std/proto(Reading) {
    id: u64
    ts: f64
}

std/channel(bad: Reading, 0)
