// The library's declaration — plain, no constraints. The constraint
// arrives later, in a module that imported this one.
import std/proto

std/proto(Server) {
    port: i64
    host: string
}
