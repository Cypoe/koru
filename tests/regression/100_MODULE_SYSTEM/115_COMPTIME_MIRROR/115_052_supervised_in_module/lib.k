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
    | retry t when t < 2 |> attempt(x: x + 1)
    | exhausted => full

pub tor seed {}
| ok
| full
seed = std/rings:enqueue(feed, v: 1)
| ok |> std/rings:enqueue(feed, v: 2)
    | ok => ok
    | full => full
| full => full
