// std/channel — the branch table is a vocabulary: `{ reading: Reading,
// alert: Alert }` is one channel firing either kind, one ring per kind.
// Sends name the kind (`send(wire, alert: a)`); consumers arm per kind.
import std/io
import std/proto
import std/channel
import std/pump

std/proto(Reading) {
    id: u64
}

std/proto(Alert) {
    level: u64
}

pub tor mk-reading { i: u64 } -> Reading
mk-reading -> { id: i }

pub tor mk-alert { l: u64 } -> Alert
mk-alert -> { level: l }

std/channel:new(wire, capacity: 8) { reading: Reading, alert: Alert }

std/channel(wire)
! reading v |> std/io:print.ln("reading {{ v.id:d }}")

std/channel(wire)
! alert a |> std/io:print.ln("alert {{ a.level:d }}")

mk-reading(i: 1): r |> std/channel:send(wire, reading: r)
| ok |> mk-alert(l: 7): a |> std/channel:send(wire, alert: a)
    | ok |> std/channel:close(wire)
        | ok |> std/io:print.ln("sealed")
    | full |> std/io:print.ln("full2")
    | closed |> std/io:print.ln("closed2")
| full |> std/io:print.ln("full1")
| closed |> std/io:print.ln("closed1")

std/pump:create(main)
| drained |> std/io:print.ln("pump drained")

std/pump(main)
! step |> wire-step()
! live |> wire-live()

std/pump:run(main)
