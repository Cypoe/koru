// Primitive price list — the koru side.
//
// Each arm isolates ONE emitted shape and runs it against zig_flat's bare-
// array equivalent. The deltas between matched arms are the per-op prices of
// store machinery: resolve, write-through, event call, announce, mint, join.
// Sinks are bit-identical with the twin by construction.

import std/io
import std/control
import std/store
import std/args
import std/string
import std/regex
import std/time
import std/grid
import std/indexes

std/store:new(cfg) { scenario: 0[i64], which: 0[i64], entities: 100000[i64], frames: 100[i64] }
std/store:new(acc) { sink: 0[i64] }

// bodies carries both guards: `act` indexed (routed), `on` unindexed (guarded).
std/store:new(bodies, capacity: 100000) { hp: i32, act: i32, on: i32 }
std/indexes:store(bodies, act)

std/store:new(watched, capacity: 100000) { v: i64 }
std/store(watched)
! v _ |> std/store:stored { acc.sink: acc.sink + 1 }

std/store:new(fresh, capacity: 100000) { hp: i32 }
std/store:new(freshix, capacity: 100000) { hp: i32, act: i32 }
std/indexes:store(freshix, act)

// bxref holds row handles (resolve arms); scratch is a plain i64 column
// (the grid RMW arm). unsafe(bounds) matches zig ReleaseFast's elided checks.
[unsafe(bounds)]std/grid:new(bxref, size: 100000) { h: 0[i64] }
[unsafe(bounds)]std/grid:new(scratch, size: 100000) { v: 0[i64] }

// -------------------------------------------------------------------- prep

tor prep-bodies {}
prep-bodies = for(0..@as(usize, @intCast(cfg.entities)))
    ! each i |> std/store:insert(bodies) { hp: @as(i32, @intCast(i * 7 % 1000)), act: @intFromBool(i % 10 == 0), on: @intFromBool(i % 8 == 0) }
        | row t |> std/grid:stored { bxref[i].h: t }

tor prep-scratch {}
prep-scratch = for(0..@as(usize, @intCast(cfg.entities)))
    ! each i |> std/grid:stored { scratch[i].v: @as(i64, @intCast(i)) }

tor prep-watched {}
prep-watched = for(0..@as(usize, @intCast(cfg.entities)))
    ! each _ |> std/store:insert(watched) { v: 0 }

tor prep {}
prep = prep-bodies() |> prep-scratch() |> prep-watched()

// -------------------------------------------------------------------- arms

// 1 read_row: sweep + per-row write-through read. There is no capture fold
// inside `! query` — the write-through IS the read arm's shape today.
tor pass-qread {}
pass-qread = std/store:query(bodies)
! query e |> std/store:stored { acc.sink: acc.sink + @as(i64, @intCast(e.hp)) }

// 2 capture_for: counted-for register fold — the baseline's inner loop.
// Reads a memory cell so LLVM cannot close-form the loop: a pure function
// of `i` folds to a constant and the arm would time nothing.
tor pass-cfor {}
pass-cfor = capture { s: 0[i64] }
    ! as c |> for(0..@as(usize, @intCast(cfg.entities)))
        ! each i |> captured { s: c.s + scratch[i].v }
    | captured final |> std/store:stored { acc.sink: acc.sink + final.s }

// 3 read_handle: resolve + column read per iteration.
tor pass-hread {}
pass-hread = capture { s: 0[i64] }
    ! as c |> for(0..@as(usize, @intCast(cfg.entities)))
        ! each i |> captured { s: c.s + @as(i64, @intCast(bodies[bxref[i].h].hp)) }
    | captured final |> std/store:stored { acc.sink: acc.sink + final.s }

// 4 write_row: per-row write event, no resolve.
tor pass-qwrite {}
pass-qwrite = std/store:query(bodies)
! query e |> std/store:stored { e.hp: e.hp - 1 }

// 5 write_handle: resolve + write event per iteration.
tor pass-hwrite {}
pass-hwrite = for(0..@as(usize, @intCast(cfg.entities)))
    ! each i |> std/store:stored { bodies[bxref[i].h].hp: bodies[bxref[i].h].hp - 1 }

// 6 write_sink: singleton write-through per iteration.
tor pass-wsink {}
pass-wsink = for(0..@as(usize, @intCast(cfg.entities)))
    ! each i |> std/store:stored { acc.sink: acc.sink + scratch[i].v }

// 7 event_call: tor call carrying a payload, body is one store write.
tor ping { v: i64 }
ping = std/store:stored { acc.sink: acc.sink + v }

tor pass-call {}
pass-call = for(0..@as(usize, @intCast(cfg.entities)))
    ! each i |> ping(v: scratch[i].v)

// 11 routed: `when` on the indexed column — bucket walk + resolve per member.
tor pass-routed {}
pass-routed = std/store:query(bodies)
! query e when e.act == 1 |> std/store:stored { acc.sink: acc.sink + @as(i64, @intCast(e.hp)) }

// 12 guarded: `when` on an unindexed column — full sweep + guard test.
tor pass-guarded {}
pass-guarded = std/store:query(bodies)
! query e when e.on == 1 |> std/store:stored { acc.sink: acc.sink + @as(i64, @intCast(e.hp)) }

// 13 watch: per-row write on a watched column — write + announce + body.
tor pass-watch {}
pass-watch = std/store:query(watched)
! query w |> std/store:stored { w.v: w.v + 1 }

// 14 grid: grid cell read-modify-write.
tor pass-grid {}
pass-grid = for(0..@as(usize, @intCast(cfg.entities)))
    ! each i |> std/grid:stored { scratch[i].v: scratch[i].v + 1 }

// --------------------------------------------------------------------- run

tor arm-1 {}
arm-1 = if(cfg.scenario == 1)
| then |> for(0..@as(usize, @intCast(cfg.frames)))
    ! each _ |> pass-qread()

tor arm-2 {}
arm-2 = if(cfg.scenario == 2)
| then |> for(0..@as(usize, @intCast(cfg.frames)))
    ! each _ |> pass-cfor()

tor arm-3 {}
arm-3 = if(cfg.scenario == 3)
| then |> for(0..@as(usize, @intCast(cfg.frames)))
    ! each _ |> pass-hread()

tor arm-4 {}
arm-4 = if(cfg.scenario == 4)
| then |> for(0..@as(usize, @intCast(cfg.frames)))
    ! each _ |> pass-qwrite()

tor arm-5 {}
arm-5 = if(cfg.scenario == 5)
| then |> for(0..@as(usize, @intCast(cfg.frames)))
    ! each _ |> pass-hwrite()

tor arm-6 {}
arm-6 = if(cfg.scenario == 6)
| then |> for(0..@as(usize, @intCast(cfg.frames)))
    ! each _ |> pass-wsink()

tor arm-7 {}
arm-7 = if(cfg.scenario == 7)
| then |> for(0..@as(usize, @intCast(cfg.frames)))
    ! each _ |> pass-call()

tor arm-8 {}
arm-8 = if(cfg.scenario == 8)
| then |> for(0..@as(usize, @intCast(cfg.entities)))
    ! each i |> std/store:insert(fresh) { hp: @as(i32, @intCast(i * 7 % 1000)) }

tor arm-9 {}
arm-9 = if(cfg.scenario == 9)
| then |> for(0..@as(usize, @intCast(cfg.entities)))
    ! each i |> std/store:insert(freshix) { hp: @as(i32, @intCast(i * 7 % 1000)), act: @intFromBool(i % 10 == 0) }

tor drain-all {}
drain-all = std/store:rule(bodies)
! row e |> std/store:take(bodies[e])
    | item _ |> _

tor arm-10 {}
arm-10 = if(cfg.scenario == 10)
| then |> drain-all()

tor arm-11 {}
arm-11 = if(cfg.scenario == 11)
| then |> for(0..@as(usize, @intCast(cfg.frames)))
    ! each _ |> pass-routed()

tor arm-12 {}
arm-12 = if(cfg.scenario == 12)
| then |> for(0..@as(usize, @intCast(cfg.frames)))
    ! each _ |> pass-guarded()

tor arm-13 {}
arm-13 = if(cfg.scenario == 13)
| then |> std/store:stored { acc.sink: 0 }
    |> for(0..@as(usize, @intCast(cfg.frames)))
        ! each _ |> pass-watch()

tor arm-14 {}
arm-14 = if(cfg.scenario == 14)
| then |> for(0..@as(usize, @intCast(cfg.frames)))
    ! each _ |> pass-grid()

tor run {}
run = arm-1() |> arm-2() |> arm-3() |> arm-4() |> arm-5() |> arm-6() |> arm-7()
    |> arm-8() |> arm-9() |> arm-10() |> arm-11() |> arm-12() |> arm-13() |> arm-14()

// ---------------------------------------------------------------- checksum
// Untimed post-state folds so write arms carry a real sink.

tor ck-qwrite {}
ck-qwrite = if(cfg.scenario == 4 or cfg.scenario == 5)
| then |> std/store:query(bodies)
    ! query e |> std/store:stored { acc.sink: acc.sink + @as(i64, @intCast(e.hp)) }

tor ck-insert {}
ck-insert = if(cfg.scenario == 8)
| then |> std/store:query(fresh)
    ! query f |> std/store:stored { acc.sink: acc.sink + @as(i64, @intCast(f.hp)) }

tor ck-insertix {}
ck-insertix = if(cfg.scenario == 9)
| then |> std/store:query(freshix)
    ! query f |> std/store:stored { acc.sink: acc.sink + @as(i64, @intCast(f.hp)) }

tor ck-watch {}
ck-watch = if(cfg.scenario == 13)
| then |> std/store:query(watched)
    ! query w |> std/store:stored { acc.sink: acc.sink + w.v }

tor ck-grid {}
ck-grid = if(cfg.scenario == 14)
| then |> for(0..@as(usize, @intCast(cfg.entities)))
    ! each i |> std/store:stored { acc.sink: acc.sink + scratch[i].v }

tor finish {}
finish = ck-qwrite() |> ck-insert() |> ck-insertix() |> ck-watch() |> ck-grid()

// -------------------------------------------------------------------- args

tor store-num { v: i64 }
store-num = if(cfg.which == 2)
| then |> std/store:stored { cfg.entities: v }
| else |> if(cfg.which == 3)
    | then |> std/store:stored { cfg.frames: v }

tor set-scenario { a: string }
set-scenario = std/regex:match(a)
| `read_row` _ |> std/store:stored { cfg.scenario: 1, cfg.which: 0 }
| `capture_for` _ |> std/store:stored { cfg.scenario: 2, cfg.which: 0 }
| `read_handle` _ |> std/store:stored { cfg.scenario: 3, cfg.which: 0 }
| `write_row` _ |> std/store:stored { cfg.scenario: 4, cfg.which: 0 }
| `write_handle` _ |> std/store:stored { cfg.scenario: 5, cfg.which: 0 }
| `write_sink` _ |> std/store:stored { cfg.scenario: 6, cfg.which: 0 }
| `event_call` _ |> std/store:stored { cfg.scenario: 7, cfg.which: 0 }
| `insert` _ |> std/store:stored { cfg.scenario: 8, cfg.which: 0 }
| `insert_idx` _ |> std/store:stored { cfg.scenario: 9, cfg.which: 0 }
| `drain` _ |> std/store:stored { cfg.scenario: 10, cfg.which: 0 }
| `routed` _ |> std/store:stored { cfg.scenario: 11, cfg.which: 0 }
| `guarded` _ |> std/store:stored { cfg.scenario: 12, cfg.which: 0 }
| `watch` _ |> std/store:stored { cfg.scenario: 13, cfg.which: 0 }
| `grid` _ |> std/store:stored { cfg.scenario: 14, cfg.which: 0 }
| no-match |> std/store:stored { cfg.scenario: 0, cfg.which: 0 }

tor take-value { a: string }
take-value = if(cfg.which == 1)
| then |> set-scenario(a)
| else |> std/string:from-page(text: a)
    | ok h |> std/string:parse-int(s: h)
        | ok v |> store-num(v)
        | err _ |> _
    | err _ |> _

tor handle-arg { a: string }
handle-arg = std/regex:match(a)
| `--scenario` _ |> std/store:stored { cfg.which: 1 }
| `--entities` _ |> std/store:stored { cfg.which: 2 }
| `--frames` _ |> std/store:stored { cfg.which: 3 }
| no-match |> take-value(a)

// -------------------------------------------------------------------- emit
// Flat gated tors, the same shape as the arm-N dispatchers — no nested
// if-else ladder, no re-derivation of a name the parse already had.

tor name-read-row {}
name-read-row = if(cfg.scenario == 1)
| then |> std/io:print("read_row")

tor name-capture-for {}
name-capture-for = if(cfg.scenario == 2)
| then |> std/io:print("capture_for")

tor name-read-handle {}
name-read-handle = if(cfg.scenario == 3)
| then |> std/io:print("read_handle")

tor name-write-row {}
name-write-row = if(cfg.scenario == 4)
| then |> std/io:print("write_row")

tor name-write-handle {}
name-write-handle = if(cfg.scenario == 5)
| then |> std/io:print("write_handle")

tor name-write-sink {}
name-write-sink = if(cfg.scenario == 6)
| then |> std/io:print("write_sink")

tor name-event-call {}
name-event-call = if(cfg.scenario == 7)
| then |> std/io:print("event_call")

tor name-insert {}
name-insert = if(cfg.scenario == 8)
| then |> std/io:print("insert")

tor name-insert-idx {}
name-insert-idx = if(cfg.scenario == 9)
| then |> std/io:print("insert_idx")

tor name-drain {}
name-drain = if(cfg.scenario == 10)
| then |> std/io:print("drain")

tor name-routed {}
name-routed = if(cfg.scenario == 11)
| then |> std/io:print("routed")

tor name-guarded {}
name-guarded = if(cfg.scenario == 12)
| then |> std/io:print("guarded")

tor name-watch {}
name-watch = if(cfg.scenario == 13)
| then |> std/io:print("watch")

tor name-grid {}
name-grid = if(cfg.scenario == 14)
| then |> std/io:print("grid")

tor emit { ns: i64 }
emit = std/io:print("{\"impl\":\"koru_price\",\"scenario\":\"")
    |> name-read-row() |> name-capture-for() |> name-read-handle() |> name-write-row() |> name-write-handle() |> name-write-sink() |> name-event-call()
    |> name-insert() |> name-insert-idx() |> name-drain() |> name-routed() |> name-guarded() |> name-watch() |> name-grid()
    |> std/io:print.ln("\",\"entities\":{{ cfg.entities:d }},\"frames\":{{ cfg.frames:d }},\"elapsed_ns\":{{ ns:d }},\"sink\":{{ acc.sink:d }}}")

// -------------------------------------------------------------------- driver

std/args:count(): n |> for(1..n)
! each i |> std/args:get(index: i)
    | arg a |> handle-arg(a)
    | out-of-bounds |> _

if(cfg.scenario == 0)
| then |> std/io:eprint.ln("koru_price: unknown or unimplemented --scenario")
| else |> prep() |> std/time:now(): t0 |> run() |> std/time:elapsed(start: t0): d |> finish()
    |> emit(ns: @as(i64, @intCast(d.ns)))
