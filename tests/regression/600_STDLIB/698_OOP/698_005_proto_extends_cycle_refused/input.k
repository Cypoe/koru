// 698_005 — extension cycles refuse: `A <: B` with `B <: A` would expand
// forever. Refused like the compound-cycle gate, naming the chain.
import std/proto

std/proto(A <: B) {
    x: i64
}

std/proto(B <: A) {
    y: i64
}
