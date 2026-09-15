import std/io
import std/proto
import std/store

std/proto:i64(Strength)
std/proto:f64(Wobble)

std/proto(Player) {
    str: Strength
}

std/proto(Enemy) {
    str: Wobble
}

std/store:new(Player, capacity: 8) { Player }
std/store:new(Enemy, capacity: 8) { Enemy }

std/store:view(Entities) {
    Player
    Enemy
}

std/store:insert(Player) { str: 18 }
std/store:insert(Enemy) { str: 2.5 }

std/store:query(Entities)
! query e |> std/io:print.ln("s {{ e.str:d }}")
