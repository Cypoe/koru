import std/io
import std/proto
import std/store

std/proto:i64(Strength)
std/proto:i64(Mana)
std/proto:i64(Armor)

std/proto(Player) {
    str: Strength
    mana: Mana
}

std/proto(Enemy) {
    str: Strength
    armor: Armor
}

std/store:new(Player, capacity: 8) { Player }
std/store:new(Enemy, capacity: 8) { Enemy }

std/store:view(Entities) {
    Player
    Enemy
}

std/store:insert(Player) { str: 18, mana: 12 }
std/store:insert(Enemy) { str: 10, armor: 5 }

std/store:query(Entities)
! query e |> std/io:print.ln("m {{ e.mana:d }}")
