// PINS: a bare-return produce may name a bound record, not only a literal —
// `-> r` against a declared `-> { a: i64, b: i64 }` repacks fieldwise into
// Output. The literal `-> { rec.a, rec.b }` (020_033's record counterpart)
// coerces at the result location; a bound value carries its own anonymous
// struct type, which Zig keeps distinct from the tor's `Output` even at
// identical shape — without the repack the emit refuses with
// "expected type 'X.Output', found 'Y.__koru_handler_impl__struct_N'".
// Covers both the `if`-arm produce and the same produce at chain tail.
import std/io

tor mk { x: i64 } -> { a: i64, b: i64 }
mk -> { a: x, b: x + 1 }

tor pick { x: i64 } -> { a: i64, b: i64 }
pick = if(x > 0)
    | then |> mk(x): r -> r
    | else |> mk(x: 0 - x): r -> r

tor chain { x: i64 } -> { a: i64, b: i64 }
chain = mk(x): r -> r

pick(x: 5): p |> std/io:print.ln("{{ p.a:d }}{{ p.b:d }}")
|> pick(x: 0 - 2): q |> std/io:print.ln("{{ q.a:d }}{{ q.b:d }}")
|> chain(x: 9): c |> std/io:print.ln("{{ c.a:d }}{{ c.b:d }}")
