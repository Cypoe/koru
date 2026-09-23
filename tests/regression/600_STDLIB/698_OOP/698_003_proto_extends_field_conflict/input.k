// 698_003 — extension field conflict: restating an inherited name with a
// DIFFERENT concept refuses. `hp` is i64 on Animal; Dog cannot redeclare it
// f64 — the merge dedups only what a shared name proves identical.
import std/proto

std/proto(Animal) {
    hp: i64
}

std/proto(Dog <: Animal) {
    hp: f64
}
