// TEST: an event that RE-ISSUES the obligation it consumes is not a discharger.
//
// The registry's discharge lookup returned the FIRST event whose declaration
// consumed the obligation. With two consumers — `use` (`<!open> -> <open!>`) and
// `shut` (`<!open>`, void) — first meant `use`, so a session's hang-up called
// the one that hands the obligation straight back and the resource survived its
// own release. The counter still went to zero, because a re-issue discharges the
// old handle before minting the new one.
//
// The compiled path has excluded this shape for as long as auto-discharge has
// existed (`eventReIssuesObligation`); only the interpreted path picked it up.
//
// Found by kopium-headless in koru-examples — an agent harness whose only tool
// is a Koru interpreter over a bridge. Its `append` verb is exactly `use`, and
// the session's hang-up wrote to the file it was closing.
//
// The bridge holds one resource; nothing in this flow discharges it, so the
// compiler inserts the hang-up. `shut` must be what runs.
//
// Both turns are flat tors reading the bridge from a store (probe_bridge_store's
// shape): a run chained inside an arm body is refused by KORU022's pipeline
// check, and its arms would attach to the wrong switch.

import std/bridge
import std/io
import std/store
import app/session

std/store:new(session, capacity: 2) { *std/bridge:Bridge<session!> }

[with]std/bridge:create(id: "s1", scope: "res"): br
|> std/store:insert(session) { br }
| row _ |> _
| full _ |> _

tor open-turn {}
open-turn = std/store:query(session)
! query br |> std/bridge:run(br, source: "open(path: \"x\")")
    | result _ |> _
    | unhandled-branch _ |> std/io:print.ln("FAIL: unhandled_branch")
    | defined d1 |> std/io:print.ln("FAIL turn1 defined {{ d1:s }}")
    | exhausted _ |> std/io:print.ln("FAIL exhausted")
    | parse-error _ |> std/io:print.ln("FAIL parse")
    | validation-error _ |> std/io:print.ln("FAIL validation")
    | shape-error _ |> std/io:print.ln("FAIL shape")
    | event-denied _ |> std/io:print.ln("FAIL denied")
    | dispatch-error e2 |> std/io:print.ln("FAIL {{ e2.message:s }}")
    | scope-not-found _ |> std/io:print.ln("FAIL scope")

tor use-turn {}
use-turn = std/store:query(session)
! query br |> std/bridge:run(br, source: "use(handle: \"res_1\")")
    | result r2 |> std/io:print.ln("after use, bridge holds {{ r2.handles:d }} handle(s) — the re-issue released nothing")
    | unhandled-branch _ |> std/io:print.ln("FAIL: unhandled_branch")
    | defined d2 |> std/io:print.ln("FAIL turn2 defined {{ d2:s }}")
    | exhausted _ |> std/io:print.ln("FAIL exhausted")
    | parse-error _ |> std/io:print.ln("FAIL parse")
    | validation-error _ |> std/io:print.ln("FAIL validation")
    | shape-error _ |> std/io:print.ln("FAIL shape")
    | event-denied _ |> std/io:print.ln("FAIL denied")
    | dispatch-error e |> std/io:print.ln("FAIL {{ e.message:s }}")
    | scope-not-found _ |> std/io:print.ln("FAIL scope")

open-turn()
use-turn()
