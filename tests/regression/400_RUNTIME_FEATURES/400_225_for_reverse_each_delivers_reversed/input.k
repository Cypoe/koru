import std/io

// `! reverse-each` is `for`'s second delivery axis: the same call walks the
// iterable back to front and hands each element to the arm's subtree. Range
// 1..5 delivers 4,3,2,1; the arm sees a plain binding — the axis lives in the
// arm name, never in a protocol object.

for(1..5)
! reverse-each i |> std/io:print.ln("{{ i:d }}")
| done |> std/io:print.ln("done")
