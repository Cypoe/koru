import std/rings
import std/io

std/rings:new(feed, capacity: 4) { value: u64 }

pub tor push { v: u64 }
| ok
| full
push = std/rings:enqueue(feed, v)
| ok => ok
| full => full

pub tor pop {}
pop = std/rings:dequeue(feed)
| some v |> std/io:print.ln("mod popped {{ v:d }}")
| none |> std/io:print.ln("mod empty")
