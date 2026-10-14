// PINS the C-lane refusal for owned columns — an owned pointer cell
// carries a lifecycle obligation the C lane's first fragment does not
// lower (insert consumes, take reissues, teardown discharges).
import std/io
import std/store
import app/lib/res

std/store:new(things, capacity: 8) { r: *app/lib/res:Resource<owned!> }

app/lib/res:new(): res |> std/store:insert(things) { r: res }
    | row row |> std/store:take(things[row])
        | item it |> app/lib/res:free(r: it) |> std/io:print.ln("freed")
