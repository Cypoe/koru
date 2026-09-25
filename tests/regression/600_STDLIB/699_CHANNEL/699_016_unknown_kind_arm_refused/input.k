// std/channel — a join arm names a kind in the channel's vocabulary or
// `closed`; anything else refuses naming the vocabulary.
import std/io
import std/proto
import std/channel

std/proto(Reading) {
    id: u64
}

std/channel:new(inbox, capacity: 8) { reading: Reading }

std/channel(inbox)
! nosuch v |> std/io:print.ln("{{ v.id:d }}")
