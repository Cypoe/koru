// std/channel — `|` arms don't parse on the join: consumers are `!` arms;
// the `|` status branches live on the send/recv/close chain steps.
import std/io
import std/proto
import std/channel

std/proto(Reading) {
    id: u64
}

std/channel:new(inbox, capacity: 8) { reading: Reading }

std/channel(inbox)
| done |> std/io:print.ln("done")
