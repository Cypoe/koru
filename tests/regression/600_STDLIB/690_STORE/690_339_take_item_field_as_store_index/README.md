# 690_339 — take item field as store index

A `| item` arm binds the taken row VALUE. A store field of it in index
position — `pool[i.opp]` — resolves the field's stored handle. The self-FK
traversal head (`store[handle.field]`, "field OF row handle") must not
fire on a row-value base: `i` is not a handle.

Two rows; `a.opp` carries b's minted handle. `take(pool[a])` swap-removes
a (b slides to slot 0 — the handle still resolves), then the item arm
writes `pool[i.opp].hp` through the taken payload. The sweep prints 99.
