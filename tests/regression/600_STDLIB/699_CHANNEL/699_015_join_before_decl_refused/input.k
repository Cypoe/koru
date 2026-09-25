// std/channel — the declaration precedes its uses in document order. A join
// above `std/channel:new` refuses with the ordering law, not an unknown
// channel.
import std/io
import std/proto
import std/channel

std/proto(Reading) {
    id: u64
}

std/channel(inbox)
! reading v |> std/io:print.ln("{{ v.id:d }}")

std/channel:new(inbox, capacity: 8) { reading: Reading }
