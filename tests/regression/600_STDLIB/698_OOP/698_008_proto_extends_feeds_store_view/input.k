// 698_008 — an extended proto feeds the store/view surface: Dog <: Animal
// and bare Cat <: Animal (an empty-block extension — the whole field set is
// inherited) each pack at their store's root, and a view over both projects
// the shared inherited `hp` leaf. `e is Dogs` narrows to the private leaf.
import std/io
import std/proto
import std/store

std/proto(Animal) {
    hp: i64
}

std/proto(Dog <: Animal) {
    woofs: i64
}

std/proto(Cat <: Animal) {}

std/store:new(Dogs, capacity: 8) { Dog }
std/store:new(Cats, capacity: 8) { Cat }

std/store:view(Animals) {
    Dogs
    Cats
}

std/store:insert(Dogs) { hp: 10, woofs: 3 }
std/store:insert(Cats) { hp: 20 }

std/store:query(Animals)
! query a |> std/io:print.ln("hp={{ a.hp:d }}")

std/store:query(Animals)
! query a when a is Dogs |> std/io:print.ln("woofs={{ a.woofs:d }}")
