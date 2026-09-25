// PINS: keyed addressing `store[key: value]` refuses at every consumer that
// would otherwise splice the bracket interior verbatim into
// `__koru_resolve(...)`, emitting invalid host code. The `key:` decl emits
// no lookup machinery today (690_018) — a consumer must honor or refuse,
// and refusal names the pin and the working spelling (store[handle]).
import std/io
import std/store

std/store:new(pool, key: id, capacity: 64) { id: i64, hp: i64 }

std/store:insert(pool) { id: 7, hp: 50 }

std/store:query(pool)
! query e |> std/store:stored { pool[id: 7].hp: e.hp - 10 }
