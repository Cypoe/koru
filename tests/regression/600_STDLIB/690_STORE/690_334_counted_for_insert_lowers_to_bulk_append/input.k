// BULK APPEND — counted `for` whose `! each` body is a single insert
// into an observation-free store lowers to one hoisted capacity check,
// indexed column writes at `base + j`, and a single `len += n` after
// the loop. The per-row path's `len += 1` is a loop-carried store that
// blocks the optimizer; measured ~294us -> ~89us on a 100k-row fill by
// hand-editing the emitted loop before the lowering existed.
//
// `marks` qualifies on every clause — no handles, no watch, no rule,
// no lifecycle arms, no `| row`/`| full` on the insert. Its `| done`
// arm carries a real body (the notes write): the bulk block hands off
// to it through the same `__koru_continue` marker the template's own
// `{{ continuations["done"].continue }}` renders to, so post-loop work
// still runs once, after the fill.
//
// `kept` declines twice over — the insert binds `| row k` (handle
// machinery stays) and an armed insert inside `! each` is not the bare
// single-insert shape. Its rows land one event call at a time, with
// the row arm firing per insert. One program, both halves of the
// recognizer's decision.
import std/io
import std/store
import std/control

std/store:new(marks, capacity: 8) { on: i64 }
std/store:new(kept, capacity: 8) { hp: i64 }
std/store:new(notes) { n: 0[i64] }

for(0..5)
! each i |> std/store:insert(marks) { on: @intCast(i * 2) }
| done |> std/store:stored { notes.n: 5 }

for(0..3)
! each i |> std/store:insert(kept) { hp: @intCast(i * 10) }
    | row k |> std/io:print.ln("row {{ k:d }}")

std/store:query(marks)
! query e |> std/io:print.ln("mark {{ e.on:d }}")

std/store:query(kept)
! query e |> std/io:print.ln("kept {{ e.hp:d }}")

std/io:print.ln("notes {{ notes.n:d }}")
