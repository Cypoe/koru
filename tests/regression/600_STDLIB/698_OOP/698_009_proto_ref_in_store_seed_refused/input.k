// 698_009 — a ref field is a row handle: in a store seed the column IS the
// handle, so `ref(Dog)` there is refused with the i64 spelling named (the
// typed-reference surface the proto layer keeps is for checker metadata,
// not a second column material).
import std/proto
import std/store

std/proto(Dog) {
    hp: i64
}

std/proto(Owner) {
    dog: ref(Dog)
}

std/store:new(owners, capacity: 8) { Owner }
