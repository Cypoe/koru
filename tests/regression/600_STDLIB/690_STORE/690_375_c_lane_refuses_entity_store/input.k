// PINS the C-lane refusal for [entity] stores — the entity substrate
// (take mints <std/store:taken!>, user-authored discharger) is outside
// the C lane's first fragment.
import std/io
import std/store

[entity(enemy)]std/store:new(enemies, capacity: 8) { hp: i64 }

pub tor discharge-enemy { enemy: Enemy<std/store:!taken> }
discharge-enemy = std/io:print.ln("despawned")

std/store:insert(enemies) { hp: 9 }
| row r |> std/store:take(enemies[r])
    | item i |> discharge-enemy(enemy: i)
