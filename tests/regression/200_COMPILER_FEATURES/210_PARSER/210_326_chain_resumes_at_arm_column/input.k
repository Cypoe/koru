// PINS: a `|>` step following an `if`'s arms resumes the chain when it
// sits at the arm column (`| then` / `| else`) — the if's continuation
// column is the arm column, not the `|> if` column.
import std/io
import std/store

std/store:new(st) { x: 0[i64] }

pub tor w { } -> i64
w = std/store:stored { st.x: 0 }
    |> if(st.x == 0)
        | then |> std/store:stored { st.x: 1 }
        | else |> std/store:stored { st.x: 2 }
        |> std/store:stored { st.x: st.x + 10 }: _ -> st.x

w(): _ -> 0
std/io:print.ln("{{ st.x:d }}")
