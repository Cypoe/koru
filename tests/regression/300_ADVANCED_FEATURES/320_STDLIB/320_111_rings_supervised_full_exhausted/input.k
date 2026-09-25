// std/rings x std/supervisor — exhaustion forwards the last outcome in
// kind: a full cap-2 ring stays full across every retry (implicit
// re-entry re-invokes the producing call, `attempt`), so `| exhausted`
// produces `full` and the caller's own `| full` arm decides what giving
// up means. Bounded backpressure with a loud, spelled exit — no silent
// unbounded block.
import std/rings
import std/supervisor
import std/io

std/rings:new(feed, capacity: 2) { value: u64 }

pub tor attempt { x: u64 }
| ok
| full

attempt = std/rings:enqueue(feed, v: x)
| ok => ok
| full => full

pub tor push { x: u64 }
| ok
| full

push = attempt(x)
| ok => ok
| full |> std/supervisor:supervised
    | retry t when t < 3
    | exhausted => full

std/rings:enqueue(feed, v: 1)
| ok |> std/rings:enqueue(feed, v: 2)
    | ok |> push(x: 3)
        | ok |> std/io:print.ln("ERROR: enqueue into full ring")
        | full |> std/io:print.ln("gave up")
    | full |> std/io:print.ln("ERROR: second enqueue")
| full |> std/io:print.ln("ERROR: first enqueue")
