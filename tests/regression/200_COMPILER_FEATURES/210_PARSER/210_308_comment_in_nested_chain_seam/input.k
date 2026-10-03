// PINS: a comment line inside a NESTED `|>` chain seam is trivia — the
// chain stays attached, same ruling as 210_239's top-level seam and the
// parser's own chainCommentDisposition ("a comment between them changes
// nothing about which steps are chained"). The stitch path that joins a
// branch head's deeper `|>` lines used to end the chain on the comment,
// orphaning the take and re-binding its arms to print's impl event
// ("event 'std.io:print.impl' has no branch 'item'"). Blank lines still
// sever — 210_307.
//
// Runtime: the second take finds a stale row handle (generation
// mismatch after the first take) and fires `| empty`.

import std/store
import std/io

std/store:new(items, capacity: 4) { v: i64 }
std/store:insert(items) { v: 42 }
| row a |> std/store:take(items[a])
    | item i |> std/io:print.ln("{{ i.v:d }}")
        // sibling-fuzz trivia — the seam under test
        |> std/store:take(items[a])
            | item j |> std/io:print.ln("{{ j.v:d }}")
            | empty |> std/io:print.ln("empty")
