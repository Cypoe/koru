// PINS: a stored write block whose second field carries a dotted head —
// `e.px: 1 e.py: 2` — fuses for want of a comma and refuses KORU161. The
// fused-field head is not only `name:`; a write head is `name.field:` or
// `name[i].field:`, and struct_literal.fusedFieldLine sees all of them.
import std/io
import std/store

std/store:new(ents, capacity: 4) { px: i64, py: i64 }

std/store:insert(ents) { px: 0, py: 0 }

std/store:query(ents)
! query e |> std/store:stored {
    e.px: 1 e.py: 2
}

std/store:query(ents)
! query r |> std/io:print.ln("p {{ r.px:d }}")
