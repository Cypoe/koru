// std/rings x std/supervisor — backpressure is a branch, so policy is a
// branch: `| full` hosts `supervised`, and `| retry`'s explicit re-entry
// calls the same tor with remapped args — `attempt(x + 1)` climbs
// values across retries while the cap-2 ring stays full, so exhaustion
// forwards `full` to the caller's own arm. Go spells this `select` +
// `time.After`; here it is a bounded fold over the failure vocabulary.
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

std/rings:enqueue(feed, v: 1)
| ok |> std/rings:enqueue(feed, v: 2)
    | ok |> push(x: 10)
        | ok |> std/io:print.ln("ERROR: enqueue into full ring")
        | full |> std/io:print.ln("gave up")
    | full |> std/io:print.ln("ERROR: second enqueue")
| full |> std/io:print.ln("ERROR: first enqueue")
