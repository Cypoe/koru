// Test: a refine violation is RE-RAISABLE — `supervise` wraps push, catches
// its `?!violated`, and produces into its OWN declared `?!violated` branch
// (`=> violated f`). The panic crosses a whole event boundary with its
// payload intact; the outer caller is the one who actually supervises.
// This is the let-it-crash shape (836) riding the refine surface: the
// intermediate layer neither swallows nor dies — it forwards.
//
// Expected: runs clean — `supervised port` for the bad push, `accepted` for
//           the good one (expected.txt).
import std/proto
import std/refine
import std/list
import std/io

std/proto(Server) {
    port: i64
    host: string
}

std/refine(Server) {
    port: i64 & >1024 & <=65535
    host: string
}

pub tor supervise { port: i64 }
| ok
| ?!violated string
| ?!err string

supervise = std/list:new(Server)
| list xs |> std/list:push(xs, port, host: "fwd")
    | ok |> std/list:free(xs) |> => ok
    | violated f |> std/list:free(xs) |> => violated f
| err e |> => err e

supervise(port: 80)
| ok |> std/io:print.ln("unexpected accept")
| violated f |> std/io:print.ln("supervised {{ f:s }}")

supervise(port: 8080)
| ok |> std/io:print.ln("accepted")
| violated f |> std/io:print.ln("supervised {{ f:s }}")
