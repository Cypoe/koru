// The sweep lives in an IMPORTED MODULE on purpose: the JS emitter walks a
// module's events through emitModuleEventDecls + eventIsJsImplementable, a
// gate entry-file flows never pass through. A sweep body whose `take` arm is
// covered only by the synthesized `| empty` panic continuation carries an
// `.inline_code` node — the walk must vouch for it, or the minted
// `__store_sweepbody_*` event is referenced by the sweeprun and never
// emitted (`undefined.handler` at runtime). 690_305 pins the same-file road.
import std/io
import std/store

std/store:new(items, capacity: 8) { v: i64 }

pub tor seed { }
seed = std/store:insert(items) { v: 10 }
    | row _ |> _
    | full |> _

pub tor collect { }
collect = std/store:query(items)
    ! query e when e.v == 10
        |> std/store:take(items[e])
            | item i |> std/io:print.ln("took {{ i.v:d }}")
