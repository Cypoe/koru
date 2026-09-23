// 698_007 — a ref must name a declared proto: `ref(Nothing)` has no target
// to point at. Refused at the proto gate like any unknown field type.
import std/proto

std/proto(Owner) {
    dog: ref(Nothing)
}
