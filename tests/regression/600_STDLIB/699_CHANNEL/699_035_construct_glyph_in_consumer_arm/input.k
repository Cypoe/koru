// Glyph discipline, the CHANNEL-CONSUMER case — sibling of 400_199 and
// 690_357-360. A `=>` inside a `std/channel(<name>)` consumer arm can never
// construct: the arm's `|>` chain grafts into the minted void unit
// (channel.units' drained-unit convention — no return contract), so the
// enclosing tor's branch cannot be produced from in there. Without this
// wall it dies in emitted Zig (`type 'void' does not support struct
// initialization syntax` inside the generated `__channel_*` handler).
import std/io
import std/proto
import std/channel
import std/pump

std/proto(Reading) { id: u64 }

pub tor mk { i: u64 } -> Reading
mk -> { id: i }

std/channel:new(inbox, capacity: 8) { reading: Reading }

std/channel(inbox)
! reading v |> std/io:print.ln("consumed {{ v.id:d }}") => ran
! closed |> std/io:print.ln("closed")

mk(i: 42): r |> std/channel:send(inbox, r)
| ok |> std/channel:close(inbox)
    | ok |> std/io:print.ln("sent+closed")
| full |> std/io:print.ln("full")
| closed |> std/io:print.ln("send closed")

std/pump:create(main)
| drained |> std/io:print.ln("pump drained")

std/pump(main)
! step |> inbox-step()
! live |> inbox-live()
! wait i |> inbox-wait(i)

std/pump:run(main)
