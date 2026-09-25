// std/rings x std/supervisor — the consumer's symmetrical arm: `| none`
// hosts `supervised` on a same-module dequeue wrapper. Re-entry calls
// the same tor (same-vocabulary law — `attempt-take` answers
// `some | none`), the empty ring stays empty across retries, and the
// forwarded `none` lands on the caller's own arm.
import std/rings
import std/supervisor
import std/io

std/rings:new(feed, capacity: 4) { value: u64 }

pub tor attempt-take { }
| some u64
| none

attempt-take = std/rings:dequeue(feed)
| some v => some v
| none => none

pub tor take { }
| some u64
| none

take = attempt-take()
| some v => some v
| none |> std/supervisor:supervised
    | retry t when t < 2

take()
| some v |> std/io:print.ln("ERROR: got {{ v:d }}")
| none |> std/io:print.ln("still none")
