// The terminal vocabulary lives in the same module as compounds. Each named
// material remains its own identity; the compound below references all four.
// String, integer, float, and boolean terminals are accepted by the same
// registry logic, without raw materials leaking into named identity.
import std/io
import std/proto

std/proto:string(Email)
std/proto:i64(UserId)
std/proto:f64(Health)
std/proto:bool(IsActive)

std/proto(Contact) {
    email: Email,
    user: UserId,
    health: Health,
    active: IsActive
}

std/io:print.ln("registered")
