// 698_006 — ref field kind: `dog: ref(Dog)` declares a value minted by an
// identity-interpreting plurality of Dog. A list of Owner carries the
// handle packed as i64 and honors the contract at push — only a handle a
// Dog-holding plurality minted may land. `| row d` is that handle, and it
// round-trips: popped from the list it still writes the same row.
import std/io
import std/proto
import std/store
import std/list

std/proto(Dog) {
    hp: i64
}

std/proto(Owner) {
    name: string
    dog: ref(Dog)
}

std/store:new(dogs, capacity: 8) { Dog }

std/store:insert(dogs) { hp: 7 }
| row d |> std/list:new(Owner)
    | list xs |> std/list:push(xs, name: "a", dog: d) |> std/list:pop(xs)
        | item v |> std/store:stored { dogs[v.dog].hp: 42 } |> std/list:free(xs)
        | empty  |> std/io:print.ln("EMPTY") |> std/list:free(xs)
    | err e |> std/io:print.ln("ERR {{ e:s }}")

std/store:query(dogs)
! query e |> std/io:print.ln("hp {{ e.hp:d }}")
