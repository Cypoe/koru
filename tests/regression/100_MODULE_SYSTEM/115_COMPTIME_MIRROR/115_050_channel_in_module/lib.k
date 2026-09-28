import std/io
import std/proto
import std/channel
import std/pump

std/proto(Reading) {
    id: u64
}

std/channel:new(inbox, capacity: 4) { reading: Reading }
std/channel:new(outbox, capacity: 4) { reading: Reading }

std/channel(inbox)
! reading v |> std/io:print.ln("mod consumed {{ v.id:d }}")
! closed |> std/io:print.ln("mod saw close")

std/pump:create(main)
| drained |> std/io:print.ln("mod pump drained")

std/pump(main)
! step |> inbox-step()
! live |> inbox-live()
! wait i |> inbox-wait(i)

pub tor mk { i: u64 } -> Reading
mk -> { id: i }

pub tor push { i: u64 }
| ok
| full
| closed
push = mk(i): r |> std/channel:send(inbox, r)
| ok => ok
| full => full
| closed => closed

pub tor post { i: u64 }
| ok
| full
| closed
post = mk(i): r |> std/channel:send(outbox, r)
| ok => ok
| full => full
| closed => closed

pub tor pull {}
pull = std/channel:recv(outbox)
| some v |> std/io:print.ln("mod got {{ v.id:d }}")
| none |> std/io:print.ln("mod none")
| closed |> std/io:print.ln("mod closed")

pub tor shutdown {}
shutdown = std/channel:close(inbox)
| ok |> std/io:print.ln("mod closed it")

pub tor seal {}
seal = std/channel:close(outbox)
| ok |> std/io:print.ln("mod sealed outbox")

pub tor go {}
go = std/pump:run(main)
