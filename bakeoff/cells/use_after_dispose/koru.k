// The bug: dispose consumes s's <live!> custody, then the program reads it.
// Refuses: the binding's tracked phantom state is gone after discharge.

import std/io
import std/proto

std/proto(Src) {
    id: i64
}

pub tor mk { i: i64 } -> Src<live!>
mk -> { id: i }

pub tor dispose { s: Src<!live> } -> i64
dispose -> s.id

pub tor peek { s: Src<live> } -> i64
peek -> s.id

mk(i: 1): s |> dispose(s): id |> std/io:print.ln("disposed {{ id:d }}")
peek(s): id |> std/io:print.ln("poisoned read {{ id:d }}")
