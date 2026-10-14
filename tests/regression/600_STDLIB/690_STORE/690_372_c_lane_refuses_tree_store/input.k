// PINS the C-lane refusal for [tree] stores — the forest substrate
// (695_STORE_TREE) is outside the C lane's first fragment.
import std/io
import std/store

[tree]std/store:new(tree, capacity: 8) { val: i64 }

std/store:insert(tree) { val: 10 }
| row root |> std/io:print.ln("root")
