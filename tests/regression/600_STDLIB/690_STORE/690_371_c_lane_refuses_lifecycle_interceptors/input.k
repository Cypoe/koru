// PINS the C-lane refusal for lifecycle interceptors — `! inserted` /
// `! removed` arms on the store decl fire from its write paths, and the
// C lane's first fragment does not lower them (store.new.kz gate).
import std/io
import std/store

std/store:new(stats) { count: 0[i64] }

std/store:new(pool, capacity: 8) { hp: i64 }
! inserted _ |> std/store:stored { stats.count: stats.count + 1 }
! removed _ |> std/store:stored { stats.count: stats.count - 1 }

std/store:insert(pool) { hp: 1 }
| row a |> std/store:insert(pool) { hp: 2 }
    | row b |> std/store:take(pool[b])
        | item _ |> _
        | empty |> _

std/io:print.ln("done")
