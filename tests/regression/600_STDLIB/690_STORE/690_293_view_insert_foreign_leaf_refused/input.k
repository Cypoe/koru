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

std/store:insert(Player) { str: 18, mana: 12, armor: 3 }

std/store:query(Entities)
! query e when e is Player |> std/io:print.ln("p {{ e.str:d }} {{ e.mana:d }}")
