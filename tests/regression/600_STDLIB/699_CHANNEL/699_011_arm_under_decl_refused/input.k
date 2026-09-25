// std/channel — `!` arms don't attach to the declaration. Consumers join at
// the bare reference `std/channel(inbox)`, program-wide, so the consumer set
// has exactly one place to be read.
import std/io
import std/proto
import std/channel

std/proto(Reading) {
    id: u64
}

std/channel:new(inbox, capacity: 8) { reading: Reading }
! reading v |> std/io:print.ln("{{ v.id:d }}")
