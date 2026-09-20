// THE PER-STORE HANDLE GATE — emitted shape. A plural store that never
// surfaces a row handle carries no handle machinery: no __koru_hslot_*
// arrays on the cell, no __koru_row_of/__koru_resolve/__koru_handle_of
// methods, no __store_take_ unit, and an insert that is capacity check +
// column writes + len++.
//
// `lean` qualifies on every clause — its inserts discard `| row` and its
// one sweep reads only `e.<field>` projections. `kept` fails the gate twice
// over (`| row k` binds the handle AND `kept[k]` addresses through it), so
// this one program pins both halves of the decision against the emitted
// backend: the lean cell and insert carry no `__koru_hslot` text at all,
// while the kept store's machinery is unchanged.
import std/io
import std/store

std/store:new(lean, capacity: 8) { hp: i64 }
std/store:new(kept, capacity: 8) { hp: i64 }

std/store:insert(lean) { hp: 1 }
| row _ |> _
| full |> _
std/store:insert(lean) { hp: 2 }
| row _ |> _
| full |> _

std/store:insert(kept) { hp: 3 }
| row k |> std/store:take(kept[k])
    | item gone |> std/io:print.ln("took {{ gone.hp:d }}")

std/store:query(lean)
! query e |> std/io:print.ln("lean {{ e.hp:d }}")
