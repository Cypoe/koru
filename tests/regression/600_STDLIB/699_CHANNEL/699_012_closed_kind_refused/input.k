// std/channel — `closed` is channel state, not a message kind. A branch
// table entry named `closed` refuses so `! closed` stays the close
// transition.
import std/proto
import std/channel

std/proto(Reading) {
    id: u64
}

std/channel:new(inbox, capacity: 8) { closed: Reading }
